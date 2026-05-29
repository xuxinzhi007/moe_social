package achievementbiz

import (
	"context"
	"strconv"
	"strings"

	achievementv1 "backend/api/achievement/v1"
	"backend/pkg/achievement"

	"gorm.io/gorm"
)

func parseUserID(raw string) (uint, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 32)
	if err != nil || id == 0 {
		return 0, ErrInvalidUserID
	}
	return uint(id), nil
}

func badgesToV1(badges []achievement.BadgeDTO) []*achievementv1.AchievementBadgeItem {
	out := make([]*achievementv1.AchievementBadgeItem, 0, len(badges))
	for _, b := range badges {
		out = append(out, &achievementv1.AchievementBadgeItem{
			Id: b.ID, Name: b.Name, Description: b.Description, Category: b.Category,
			Rarity: b.Rarity, Condition: b.Condition, RequiredCount: int32(b.RequiredCount),
			CurrentCount: int32(b.CurrentCount), Progress: b.Progress, IsUnlocked: b.IsUnlocked,
			UnlockedAt: b.UnlockedAt,
		})
	}
	return out
}

func unlocksToV1(unlocks []achievement.UnlockResult) []*achievementv1.AchievementUnlock {
	if len(unlocks) == 0 {
		return nil
	}
	out := make([]*achievementv1.AchievementUnlock, 0, len(unlocks))
	for _, u := range unlocks {
		out = append(out, &achievementv1.AchievementUnlock{
			BadgeId: u.BadgeID, Name: u.Name, ExpGranted: int32(u.ExpGranted),
			LevelUp: u.LevelUp, NewLevel: int32(u.NewLevel),
		})
	}
	return out
}

// ListBadges 用户成就列表（含未解锁）。
func ListBadges(ctx context.Context, store Store, userIDRaw string) ([]*achievementv1.AchievementBadgeItem, error) {
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
	return badgesToV1(badges), nil
}

// ListUnlockedBadges 已解锁成就。
func ListUnlockedBadges(ctx context.Context, store Store, userIDRaw string) ([]*achievementv1.AchievementBadgeItem, error) {
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
	return badgesToV1(unlocked), nil
}

// GetSummary 成就汇总。
func GetSummary(ctx context.Context, store Store, userIDRaw string) (*achievementv1.AchievementSummary, error) {
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
		return &achievementv1.AchievementSummary{}, nil
	}
	return &achievementv1.AchievementSummary{
		TotalBadges: int32(summary.TotalBadges), UnlockedBadges: int32(summary.UnlockedBadges),
		CompletionPercentage: summary.CompletionPercentage,
	}, nil
}

// EnsureInitialized 初始化用户成就（welcome 等）。
func EnsureInitialized(ctx context.Context, store Store, userIDRaw string) ([]*achievementv1.AchievementUnlock, error) {
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
	return unlocksToV1(unlocks), nil
}
