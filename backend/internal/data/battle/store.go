// Package battledata provides GORM persistence for the battle domain.
package battledata

import (
	"context"
	"fmt"

	battlebiz "backend/internal/biz/battle"
	"backend/internal/biz/gift"
	"backend/internal/data/gift"
	"backend/model"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type store struct{ db *gorm.DB }

// NewStore creates the battle persistence adapter.
func NewStore(db *gorm.DB) battlebiz.Store {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) CreateRoom(ctx context.Context, room *model.BattleRoom, scores []model.BattleScore) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(room).Error; err != nil {
			return fmt.Errorf("create room: %w", err)
		}
		for index := range scores {
			scores[index].RoomID = room.ID
		}
		if err := tx.Create(&scores).Error; err != nil {
			return fmt.Errorf("create scores: %w", err)
		}
		return nil
	})
}

func (s *store) GetRoom(ctx context.Context, roomID uint) (model.BattleRoom, error) {
	var room model.BattleRoom
	err := s.db.WithContext(ctx).First(&room, roomID).Error
	return room, err
}
func (s *store) GetScores(ctx context.Context, roomID uint) ([]model.BattleScore, error) {
	var scores []model.BattleScore
	err := s.db.WithContext(ctx).Where("room_id = ?", roomID).Find(&scores).Error
	return scores, err
}
func (s *store) GetParticipant(ctx context.Context, userID uint) (battlebiz.BattleParticipant, error) {
	var user model.User
	if err := s.db.WithContext(ctx).First(&user, userID).Error; err != nil {
		return battlebiz.BattleParticipant{}, err
	}
	return battlebiz.BattleParticipant{UserID: user.ID, UserName: user.Username, AvatarURL: user.Avatar}, nil
}
func (s *store) Transaction(ctx context.Context, fn func(battlebiz.Tx) error) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error { return fn(&storeTx{tx: tx}) })
}

type storeTx struct{ tx *gorm.DB }

func (s *storeTx) LockRoom(roomID uint) (model.BattleRoom, error) {
	var room model.BattleRoom
	err := s.tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&room, roomID).Error
	return room, err
}
func (s *storeTx) SaveRoom(room *model.BattleRoom) error { return s.tx.Save(room).Error }
func (s *storeTx) GetScoresForUpdate(roomID uint) ([]model.BattleScore, error) {
	var scores []model.BattleScore
	err := s.tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("room_id = ?", roomID).Find(&scores).Error
	return scores, err
}
func (s *storeTx) SaveScore(score *model.BattleScore) error { return s.tx.Save(score).Error }
func (s *storeTx) FindIdempotency(roomID, senderUserID uint, requestID string) (model.BattleIdempotencyKey, error) {
	var key model.BattleIdempotencyKey
	err := s.tx.Where("room_id = ? AND sender_user_id = ? AND request_id = ?", roomID, senderUserID, requestID).First(&key).Error
	return key, err
}
func (s *storeTx) GetEvent(eventID uint) (model.BattleGiftEvent, error) {
	var event model.BattleGiftEvent
	err := s.tx.First(&event, eventID).Error
	return event, err
}
func (s *storeTx) CreateEvent(event *model.BattleGiftEvent) error { return s.tx.Create(event).Error }
func (s *storeTx) CreateIdempotency(key *model.BattleIdempotencyKey) error {
	return s.tx.Create(key).Error
}
func (s *storeTx) SendGift(fromUserID, toUserID, giftID uint, quantity int, description string) (model.GiftRecord, model.Gift, error) {
	return giftbiz.SendInTransaction(giftdata.NewTransaction(s.tx), fromUserID, toUserID, giftID, quantity, description)
}

var _ battlebiz.Store = (*store)(nil)
var _ battlebiz.Tx = (*storeTx)(nil)
