package httplegacy

import (
	"backend/internal/legacy/types"
	achievementbiz "backend/internal/biz/achievement"
	"backend/rpc/pb/moe"
)

func achievementBadgesFromRPC(items []*moe.AchievementBadgeItem) []types.AchievementBadgeItem {
	return achievementBadgesToTypes(achievementbiz.BadgesFromRPC(items))
}

func achievementUnlocksFromRPC(items []*moe.AchievementUnlock) []types.AchievementUnlock {
	return achievementUnlocksToTypes(achievementbiz.UnlocksFromRPC(items))
}

func achievementBadgesToTypes(items []achievementbiz.BadgeItem) []types.AchievementBadgeItem {
	if len(items) == 0 {
		return []types.AchievementBadgeItem{}
	}
	out := make([]types.AchievementBadgeItem, len(items))
	for i, b := range items {
		out[i] = types.AchievementBadgeItem{
			Id: b.Id, Name: b.Name, Description: b.Description, Category: b.Category,
			Rarity: b.Rarity, Condition: b.Condition, RequiredCount: b.RequiredCount,
			CurrentCount: b.CurrentCount, Progress: b.Progress, IsUnlocked: b.IsUnlocked,
			UnlockedAt: b.UnlockedAt,
		}
	}
	return out
}

func achievementUnlocksToTypes(items []achievementbiz.UnlockItem) []types.AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]types.AchievementUnlock, len(items))
	for i, u := range items {
		out[i] = types.AchievementUnlock{
			BadgeId: u.BadgeId, Name: u.Name, ExpGranted: u.ExpGranted,
			LevelUp: u.LevelUp, NewLevel: u.NewLevel,
		}
	}
	return out
}
