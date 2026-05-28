package achievementbiz

import (
	"context"
	"strconv"
	"strings"

	"backend/pkg/achievement"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

func parseUserID(raw string) (uint, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 32)
	if err != nil || id == 0 {
		return 0, ErrInvalidUserID
	}
	return uint(id), nil
}

// ListBadges 用户成就列表（含未解锁）。
func ListBadges(ctx context.Context, store Store, userIDRaw string) ([]*moe.AchievementBadgeItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(userIDRaw)
	if err != nil {
		return nil, err
	}
	badges, err := store.ListUserAchievements(ctx, userID, true)
	if err != nil {
		return nil, err
	}
	return achievement.BadgesToProto(badges), nil
}

// ListUnlockedBadges 已解锁成就。
func ListUnlockedBadges(ctx context.Context, store Store, userIDRaw string) ([]*moe.AchievementBadgeItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(userIDRaw)
	if err != nil {
		return nil, err
	}
	all, err := store.ListUserAchievements(ctx, userID, true)
	if err != nil {
		return nil, err
	}
	unlocked := make([]achievement.BadgeDTO, 0)
	for _, b := range all {
		if b.IsUnlocked {
			unlocked = append(unlocked, b)
		}
	}
	return achievement.BadgesToProto(unlocked), nil
}

// GetSummary 成就汇总。
func GetSummary(ctx context.Context, store Store, userIDRaw string) (*moe.AchievementSummary, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(userIDRaw)
	if err != nil {
		return nil, err
	}
	summary, err := store.GetSummary(ctx, userID)
	if err != nil {
		return nil, err
	}
	if summary == nil {
		return &moe.AchievementSummary{}, nil
	}
	return &moe.AchievementSummary{
		TotalBadges: int32(summary.TotalBadges), UnlockedBadges: int32(summary.UnlockedBadges),
		CompletionPercentage: summary.CompletionPercentage,
	}, nil
}

// EnsureInitialized 初始化用户成就（welcome 等）。
func EnsureInitialized(ctx context.Context, store Store, userIDRaw string) ([]*moe.AchievementUnlock, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(userIDRaw)
	if err != nil {
		return nil, err
	}
	unlocks, err := store.EnsureUserInitialized(ctx, userID)
	if err != nil {
		return nil, err
	}
	return achievement.UnlocksToProto(unlocks), nil
}
