package petdata

import (
	"context"
	"errors"
	"fmt"

	"backend/model"

	"gorm.io/gorm"
)

// Repo GORM 实现。
type Repo struct {
	db *gorm.DB
}

// NewRepo 创建仓储。
func NewRepo(db *gorm.DB) *Repo {
	return &Repo{db: db}
}

// GetByUserID 按用户取档案。
func (r *Repo) GetByUserID(ctx context.Context, userID string) (*model.PetProfile, error) {
	var p model.PetProfile
	err := r.db.WithContext(ctx).Where("user_id = ?", userID).First(&p).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if err != nil {
		return nil, fmt.Errorf("pet get: %w", err)
	}
	return &p, nil
}

// Save 保存档案。
func (r *Repo) Save(ctx context.Context, p *model.PetProfile) error {
	if p.ID == 0 {
		if err := r.db.WithContext(ctx).Create(p).Error; err != nil {
			return fmt.Errorf("pet create: %w", err)
		}
		return nil
	}
	if err := r.db.WithContext(ctx).Save(p).Error; err != nil {
		return fmt.Errorf("pet save: %w", err)
	}
	return nil
}

// ListFriends 好友列表。
func (r *Repo) ListFriends(ctx context.Context, userID string) ([]model.PetFriendship, error) {
	var list []model.PetFriendship
	if err := r.db.WithContext(ctx).Where("user_id = ?", userID).Find(&list).Error; err != nil {
		return nil, fmt.Errorf("pet friends: %w", err)
	}
	return list, nil
}

// UpsertFriend 写入好友。
func (r *Repo) UpsertFriend(ctx context.Context, f *model.PetFriendship) error {
	var existing model.PetFriendship
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND friend_id = ?", f.UserID, f.FriendID).
		First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return r.db.WithContext(ctx).Create(f).Error
	}
	if err != nil {
		return err
	}
	existing.Status = f.Status
	return r.db.WithContext(ctx).Save(&existing).Error
}
