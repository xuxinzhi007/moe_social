// Package battleapp exposes the battle domain to transports.
package battleapp

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"time"

	battlev1 "backend/api/battle/v1"
	battlebiz "backend/internal/biz/battle"
	battledata "backend/internal/data/battle"
	"backend/model"

	"gorm.io/gorm"
)

// AppService coordinates PK operations and post-commit broadcasts.
type AppService struct {
	manager *battlebiz.Manager
	hub     *Hub
}

// New creates the application service and its in-process WebSocket hub.
func New(db *gorm.DB) *AppService {
	store := battledata.NewStore(db)
	if store == nil {
		return nil
	}
	return &AppService{manager: battlebiz.NewManager(store), hub: NewHub()}
}

// Hub returns the read-only real-time publisher.
func (s *AppService) Hub() *Hub {
	if s == nil {
		return nil
	}
	return s.hub
}

// CreateRoom creates a draft PK room for the current participant.
func (s *AppService) CreateRoom(ctx context.Context, in *battlev1.CreateRoomRequest) (*battlev1.BattleRoomReply, error) {
	actorID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	snapshot, err := s.manager.CreateRoom(ctx, actorID, uint(in.GetLeftUserId()), uint(in.GetRightUserId()))
	if err != nil {
		return nil, err
	}
	return &battlev1.BattleRoomReply{Room: snapshotToProto(snapshot)}, nil
}

// GetRoom returns the current server-authoritative snapshot.
func (s *AppService) GetRoom(ctx context.Context, in *battlev1.GetRoomRequest) (*battlev1.BattleRoomReply, error) {
	snapshot, err := s.manager.GetSnapshot(ctx, uint(in.GetRoomId()))
	if err != nil {
		return nil, err
	}
	if snapshot.Room.Status == model.BattleRoomRunning && snapshot.Room.EndsAt != nil && !time.Now().Before(*snapshot.Room.EndsAt) {
		snapshot, err = s.manager.FinishRoom(ctx, uint(in.GetRoomId()), time.Now())
		if err != nil {
			return nil, err
		}
		s.hub.PublishSnapshot("room_finished", snapshotToProto(snapshot))
	}
	return &battlev1.BattleRoomReply{Room: snapshotToProto(snapshot)}, nil
}

// StartRoom starts a draft room once and publishes its committed snapshot.
func (s *AppService) StartRoom(ctx context.Context, in *battlev1.StartRoomRequest) (*battlev1.BattleRoomReply, error) {
	actorID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	snapshot, err := s.manager.StartRoom(ctx, actorID, uint(in.GetRoomId()), time.Now())
	if err != nil {
		return nil, err
	}
	s.hub.PublishSnapshot("room_started", snapshotToProto(snapshot))
	return &battlev1.BattleRoomReply{Room: snapshotToProto(snapshot)}, nil
}

// SendBattleGift consumes a gift once per request id and broadcasts after commit.
func (s *AppService) SendBattleGift(ctx context.Context, in *battlev1.SendBattleGiftRequest) (*battlev1.SendBattleGiftReply, error) {
	senderID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	side, err := sideFromProto(in.GetSide())
	if err != nil {
		return nil, err
	}
	event, snapshot, err := s.manager.SendGift(ctx, senderID, uint(in.GetRoomId()), uint(in.GetGiftId()), side, int(in.GetQuantity()), in.GetRequestId(), time.Now())
	if err != nil {
		return nil, err
	}
	protoEvent := eventToProto(event)
	s.hub.PublishGift(protoEvent, snapshotToProto(snapshot))
	return &battlev1.SendBattleGiftReply{Room: snapshotToProto(snapshot), Event: protoEvent}, nil
}

// FinishRoom finishes an elapsed room and broadcasts the durable result.
func (s *AppService) FinishRoom(ctx context.Context, in *battlev1.FinishRoomRequest) (*battlev1.BattleRoomReply, error) {
	snapshot, err := s.manager.FinishRoom(ctx, uint(in.GetRoomId()), time.Now())
	if err != nil {
		return nil, err
	}
	s.hub.PublishSnapshot("room_finished", snapshotToProto(snapshot))
	return &battlev1.BattleRoomReply{Room: snapshotToProto(snapshot)}, nil
}

func snapshotToProto(snapshot battlebiz.Snapshot) *battlev1.BattleRoomSnapshot {
	return &battlev1.BattleRoomSnapshot{RoomId: uint64(snapshot.Room.ID), Status: statusToProto(snapshot.Room.Status), Left: participantToProto(snapshot.Left), Right: participantToProto(snapshot.Right), LeftScore: scoreToProto(snapshot.LeftScore), RightScore: scoreToProto(snapshot.RightScore), StartedAt: timeString(snapshot.Room.StartedAt), EndsAt: timeString(snapshot.Room.EndsAt), ServerTime: time.Now().UTC().Format(time.RFC3339Nano), WinnerSide: sideToProto(snapshot.Room.WinnerSide), LastEventSeq: snapshot.Room.EventSeq}
}
func participantToProto(value battlebiz.BattleParticipant) *battlev1.BattleParticipant {
	return &battlev1.BattleParticipant{UserId: uint64(value.UserID), UserName: value.UserName, AvatarUrl: value.AvatarURL}
}
func scoreToProto(value model.BattleScore) *battlev1.BattleScore {
	return &battlev1.BattleScore{Side: sideToProto(value.Side), Score: value.Score, GiftValue: value.GiftValue}
}
func eventToProto(value battlebiz.GiftEvent) *battlev1.BattleGiftEvent {
	return &battlev1.BattleGiftEvent{EventId: uint64(value.Event.ID), EventSeq: value.Event.EventSeq, SenderUserId: uint64(value.Event.SenderUserID), Side: sideToProto(value.Event.Side), GiftId: uint64(value.Gift.ID), GiftName: value.Gift.Name, GiftIcon: value.Gift.Icon, Quantity: int32(value.Event.Quantity), ScoreDelta: value.Event.ScoreDelta, LeftScore: scoreToProto(value.LeftScore), RightScore: scoreToProto(value.RightScore), CreatedAt: value.Event.CreatedAt.UTC().Format(time.RFC3339Nano)}
}
func statusToProto(status string) battlev1.BattleRoomStatus {
	switch status {
	case "draft":
		return battlev1.BattleRoomStatus_BATTLE_ROOM_STATUS_DRAFT
	case "running":
		return battlev1.BattleRoomStatus_BATTLE_ROOM_STATUS_RUNNING
	case "finished":
		return battlev1.BattleRoomStatus_BATTLE_ROOM_STATUS_FINISHED
	default:
		return battlev1.BattleRoomStatus_BATTLE_ROOM_STATUS_UNSPECIFIED
	}
}
func sideToProto(side string) battlev1.BattleSide {
	if side == "left" {
		return battlev1.BattleSide_BATTLE_SIDE_LEFT
	}
	if side == "right" {
		return battlev1.BattleSide_BATTLE_SIDE_RIGHT
	}
	return battlev1.BattleSide_BATTLE_SIDE_UNSPECIFIED
}
func sideFromProto(side battlev1.BattleSide) (string, error) {
	switch side {
	case battlev1.BattleSide_BATTLE_SIDE_LEFT:
		return "left", nil
	case battlev1.BattleSide_BATTLE_SIDE_RIGHT:
		return "right", nil
	default:
		return "", fmt.Errorf("%w: side", battlebiz.ErrInvalidRequest)
	}
}
func timeString(value *time.Time) string {
	if value == nil {
		return ""
	}
	return value.UTC().Format(time.RFC3339Nano)
}

func actorUserID(ctx context.Context) (uint, error) {
	for _, key := range []string{"userId", "user_id"} {
		if raw, ok := ctx.Value(key).(string); ok {
			value, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 64)
			if err == nil && value > 0 {
				return uint(value), nil
			}
		}
	}
	return 0, fmt.Errorf("%w: authenticated user", battlebiz.ErrInvalidRequest)
}
