package arenadata

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

// GetByUserID 按用户取存档。
func (r *Repo) GetByUserID(ctx context.Context, userID string) (*model.ArenaProfile, error) {
	var p model.ArenaProfile
	err := r.db.WithContext(ctx).Where("user_id = ?", userID).First(&p).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if err != nil {
		return nil, fmt.Errorf("arena get: %w", err)
	}
	return &p, nil
}

// Save 保存存档。
func (r *Repo) Save(ctx context.Context, p *model.ArenaProfile) error {
	if p.ID == 0 {
		if err := r.db.WithContext(ctx).Create(p).Error; err != nil {
			return fmt.Errorf("arena create: %w", err)
		}
		return nil
	}
	if err := r.db.WithContext(ctx).Save(p).Error; err != nil {
		return fmt.Errorf("arena save: %w", err)
	}
	return nil
}
