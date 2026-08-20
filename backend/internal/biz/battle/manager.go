// Package battlebiz contains the server-authoritative gift PK rules.
package battlebiz

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"backend/model"
)

const RoomDuration = 120 * time.Second

var (
	ErrRoomNotFound   = errors.New("battle room not found")
	ErrRoomNotRunning = errors.New("battle room is not running")
	ErrRoomFinished   = errors.New("battle room has finished")
	ErrInvalidSide    = errors.New("invalid battle side")
	ErrInvalidRequest = errors.New("invalid battle request")
	ErrPermission     = errors.New("battle operation is not permitted")
)

// Store hides persistence and the shared Gift transaction port from battle rules.
type Store interface {
	CreateRoom(ctx context.Context, room *model.BattleRoom, scores []model.BattleScore) error
	GetRoom(ctx context.Context, roomID uint) (model.BattleRoom, error)
	GetScores(ctx context.Context, roomID uint) ([]model.BattleScore, error)
	GetParticipant(ctx context.Context, userID uint) (BattleParticipant, error)
	Transaction(ctx context.Context, fn func(Tx) error) error
}

// Tx is the lock-scoped mutation boundary for one PK room.
type Tx interface {
	LockRoom(roomID uint) (model.BattleRoom, error)
	SaveRoom(room *model.BattleRoom) error
	GetScoresForUpdate(roomID uint) ([]model.BattleScore, error)
	SaveScore(score *model.BattleScore) error
	FindIdempotency(roomID, senderUserID uint, requestID string) (model.BattleIdempotencyKey, error)
	GetEvent(eventID uint) (model.BattleGiftEvent, error)
	CreateEvent(event *model.BattleGiftEvent) error
	CreateIdempotency(key *model.BattleIdempotencyKey) error
	SendGift(fromUserID, toUserID, giftID uint, quantity int, description string) (model.GiftRecord, model.Gift, error)
}

// BattleParticipant is the minimal display identity contained in snapshots.
type BattleParticipant struct {
	UserID    uint
	UserName  string
	AvatarURL string
}

// Snapshot is the domain representation returned to HTTP and WebSocket adapters.
type Snapshot struct {
	Room       model.BattleRoom
	Left       BattleParticipant
	Right      BattleParticipant
	LeftScore  model.BattleScore
	RightScore model.BattleScore
}

// GiftEvent joins a durable event with its gift display data.
type GiftEvent struct {
	Event      model.BattleGiftEvent
	Gift       model.Gift
	LeftScore  model.BattleScore
	RightScore model.BattleScore
}

// Manager enforces PK lifecycle and scoring rules.
type Manager struct{ store Store }

// NewManager creates a battle rule manager.
func NewManager(store Store) *Manager { return &Manager{store: store} }

// CreateRoom creates a draft room with exactly two different participants.
func (m *Manager) CreateRoom(ctx context.Context, actorID, leftUserID, rightUserID uint) (Snapshot, error) {
	if m == nil || m.store == nil || actorID == 0 || leftUserID == 0 || rightUserID == 0 || leftUserID == rightUserID {
		return Snapshot{}, ErrInvalidRequest
	}
	if actorID != leftUserID && actorID != rightUserID {
		return Snapshot{}, ErrPermission
	}
	room := model.BattleRoom{LeftUserID: leftUserID, RightUserID: rightUserID, Status: model.BattleRoomDraft}
	scores := []model.BattleScore{{Side: model.BattleSideLeft}, {Side: model.BattleSideRight}}
	if err := m.store.CreateRoom(ctx, &room, scores); err != nil {
		return Snapshot{}, fmt.Errorf("create battle room: %w", err)
	}
	return m.GetSnapshot(ctx, room.ID)
}

// GetSnapshot loads server time anchors and both materialized scores.
func (m *Manager) GetSnapshot(ctx context.Context, roomID uint) (Snapshot, error) {
	if m == nil || m.store == nil || roomID == 0 {
		return Snapshot{}, ErrInvalidRequest
	}
	room, err := m.store.GetRoom(ctx, roomID)
	if err != nil {
		return Snapshot{}, fmt.Errorf("get battle room %d: %w", roomID, err)
	}
	return m.snapshot(ctx, room)
}

// StartRoom transitions a draft to running and fixes the server clock anchor.
func (m *Manager) StartRoom(ctx context.Context, actorID, roomID uint, now time.Time) (Snapshot, error) {
	if actorID == 0 || roomID == 0 {
		return Snapshot{}, ErrInvalidRequest
	}
	var room model.BattleRoom
	err := m.store.Transaction(ctx, func(tx Tx) error {
		locked, err := tx.LockRoom(roomID)
		if err != nil {
			return err
		}
		if actorID != locked.LeftUserID && actorID != locked.RightUserID {
			return ErrPermission
		}
		if locked.Status == model.BattleRoomFinished {
			return ErrRoomFinished
		}
		if locked.Status == model.BattleRoomDraft {
			endsAt := now.UTC().Add(RoomDuration)
			locked.Status = model.BattleRoomRunning
			locked.StartedAt = ptrTime(now.UTC())
			locked.EndsAt = &endsAt
			if err := tx.SaveRoom(&locked); err != nil {
				return err
			}
		}
		room = locked
		return nil
	})
	if err != nil {
		return Snapshot{}, err
	}
	return m.snapshot(ctx, room)
}

// FinishRoom finalizes a room once, based only on the server clock and scores.
func (m *Manager) FinishRoom(ctx context.Context, roomID uint, now time.Time) (Snapshot, error) {
	if roomID == 0 {
		return Snapshot{}, ErrInvalidRequest
	}
	var room model.BattleRoom
	err := m.store.Transaction(ctx, func(tx Tx) error {
		locked, err := tx.LockRoom(roomID)
		if err != nil {
			return err
		}
		if locked.Status == model.BattleRoomFinished {
			room = locked
			return nil
		}
		if locked.Status != model.BattleRoomRunning || locked.EndsAt == nil || now.Before(*locked.EndsAt) {
			return ErrRoomNotRunning
		}
		scores, err := tx.GetScoresForUpdate(roomID)
		if err != nil {
			return err
		}
		left, right := scoresBySide(scores)
		locked.Status = model.BattleRoomFinished
		if left.Score > right.Score {
			locked.WinnerSide = model.BattleSideLeft
		} else if right.Score > left.Score {
			locked.WinnerSide = model.BattleSideRight
		}
		if err := tx.SaveRoom(&locked); err != nil {
			return err
		}
		room = locked
		return nil
	})
	if err != nil {
		return Snapshot{}, err
	}
	return m.snapshot(ctx, room)
}

// SendGift consumes an existing gift and commits its event and score atomically.
func (m *Manager) SendGift(ctx context.Context, senderID, roomID, giftID uint, side string, quantity int, requestID string, now time.Time) (GiftEvent, Snapshot, error) {
	if senderID == 0 || roomID == 0 || giftID == 0 || quantity <= 0 || !validSide(side) || strings.TrimSpace(requestID) == "" {
		return GiftEvent{}, Snapshot{}, ErrInvalidRequest
	}
	var event GiftEvent
	var room model.BattleRoom
	err := m.store.Transaction(ctx, func(tx Tx) error {
		locked, err := tx.LockRoom(roomID)
		if err != nil {
			return err
		}
		if locked.Status != model.BattleRoomRunning {
			return ErrRoomNotRunning
		}
		if locked.EndsAt == nil || !now.Before(*locked.EndsAt) {
			return ErrRoomFinished
		}
		if key, err := tx.FindIdempotency(roomID, senderID, requestID); err == nil {
			durable, eventErr := tx.GetEvent(key.EventID)
			if eventErr != nil {
				return eventErr
			}
			scores, scoreErr := tx.GetScoresForUpdate(roomID)
			if scoreErr != nil {
				return scoreErr
			}
			left, right := scoresBySide(scores)
			event.Event = durable
			event.LeftScore = left
			event.RightScore = right
			room = locked
			return nil
		}
		scores, err := tx.GetScoresForUpdate(roomID)
		if err != nil {
			return err
		}
		left, right := scoresBySide(scores)
		receiverID := locked.LeftUserID
		if side == model.BattleSideRight {
			receiverID = locked.RightUserID
		}
		record, gift, err := tx.SendGift(senderID, receiverID, giftID, quantity, fmt.Sprintf("PK 房间 %d 送出礼物「%%s」×%d", roomID, quantity))
		if err != nil {
			return err
		}
		locked.EventSeq++
		scoreDelta := int64(gift.Price * quantity)
		selected := &left
		if side == model.BattleSideRight {
			selected = &right
		}
		selected.Score += scoreDelta
		selected.GiftValue += scoreDelta
		if err := tx.SaveScore(selected); err != nil {
			return err
		}
		if err := tx.SaveRoom(&locked); err != nil {
			return err
		}
		durable := model.BattleGiftEvent{RoomID: roomID, EventSeq: locked.EventSeq, SenderUserID: senderID, Side: side, GiftRecordID: record.ID, GiftID: giftID, Quantity: quantity, ScoreDelta: scoreDelta}
		if err := tx.CreateEvent(&durable); err != nil {
			return err
		}
		if err := tx.CreateIdempotency(&model.BattleIdempotencyKey{RoomID: roomID, SenderUserID: senderID, RequestID: requestID, EventID: durable.ID}); err != nil {
			return err
		}
		event = GiftEvent{Event: durable, Gift: gift, LeftScore: left, RightScore: right}
		room = locked
		return nil
	})
	if err != nil {
		return GiftEvent{}, Snapshot{}, err
	}
	snapshot, err := m.snapshot(ctx, room)
	if err != nil {
		return GiftEvent{}, Snapshot{}, err
	}
	return event, snapshot, nil
}

func (m *Manager) snapshot(ctx context.Context, room model.BattleRoom) (Snapshot, error) {
	scores, err := m.store.GetScores(ctx, room.ID)
	if err != nil {
		return Snapshot{}, fmt.Errorf("get battle scores: %w", err)
	}
	left, right := scoresBySide(scores)
	leftUser, err := m.store.GetParticipant(ctx, room.LeftUserID)
	if err != nil {
		return Snapshot{}, err
	}
	rightUser, err := m.store.GetParticipant(ctx, room.RightUserID)
	if err != nil {
		return Snapshot{}, err
	}
	return Snapshot{Room: room, Left: leftUser, Right: rightUser, LeftScore: left, RightScore: right}, nil
}

func scoresBySide(scores []model.BattleScore) (model.BattleScore, model.BattleScore) {
	var left, right model.BattleScore
	for _, score := range scores {
		if score.Side == model.BattleSideLeft {
			left = score
		} else if score.Side == model.BattleSideRight {
			right = score
		}
	}
	return left, right
}
func validSide(side string) bool {
	return side == model.BattleSideLeft || side == model.BattleSideRight
}
func ptrTime(value time.Time) *time.Time { return &value }
