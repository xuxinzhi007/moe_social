package achievementbiz

import (
	"context"

	"backend/pkg/achievement"
)

// Store 成就持久化（P4-D2；默认由 internal/data/achievement 实现）。
type Store interface {
	ListUserAchievements(ctx context.Context, userID uint, includeAll bool) ([]achievement.BadgeDTO, error)
	GetSummary(ctx context.Context, userID uint) (*achievement.SummaryDTO, error)
	EnsureUserInitialized(ctx context.Context, userID uint) ([]achievement.UnlockResult, error)
}
