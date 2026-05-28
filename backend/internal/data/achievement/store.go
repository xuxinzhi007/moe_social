package achievementdata

import (
	"context"

	achievementbiz "backend/internal/biz/achievement"
	"backend/pkg/achievement"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.Store（P4-D2）。
func NewStore(db *gorm.DB) achievementbiz.Store {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) engine() *achievement.Engine {
	return achievement.NewEngine(s.db)
}

func (s *store) ListUserAchievements(ctx context.Context, userID uint, includeAll bool) ([]achievement.BadgeDTO, error) {
	return s.engine().ListUserAchievements(s.db.WithContext(ctx), userID, includeAll)
}

func (s *store) GetSummary(ctx context.Context, userID uint) (*achievement.SummaryDTO, error) {
	return s.engine().GetSummary(s.db.WithContext(ctx), userID)
}

func (s *store) EnsureUserInitialized(ctx context.Context, userID uint) ([]achievement.UnlockResult, error) {
	tx := s.db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}
	engine := achievement.NewEngine(s.db)
	unlocks, err := engine.EnsureUserInitialized(tx, userID)
	if err != nil {
		tx.Rollback()
		return nil, err
	}
	if err := tx.Commit().Error; err != nil {
		return nil, err
	}
	return unlocks, nil
}
