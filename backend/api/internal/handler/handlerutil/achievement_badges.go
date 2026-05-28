//go:build hybrid

package handlerutil

import (
	"backend/api/internal/types"
	achievementbiz "backend/internal/biz/achievement"
	"backend/rpc/pb/moe"
)

// BadgesFromRPC 成就徽章 proto → API types。
func BadgesFromRPC(items []*moe.AchievementBadgeItem) []types.AchievementBadgeItem {
	bizItems := achievementbiz.BadgesFromRPC(items)
	if len(bizItems) == 0 {
		return []types.AchievementBadgeItem{}
	}
	out := make([]types.AchievementBadgeItem, len(bizItems))
	for i, b := range bizItems {
		out[i] = types.AchievementBadgeItem{
			Id: b.Id, Name: b.Name, Description: b.Description, Category: b.Category,
			Rarity: b.Rarity, Condition: b.Condition, RequiredCount: b.RequiredCount,
			CurrentCount: b.CurrentCount, Progress: b.Progress, IsUnlocked: b.IsUnlocked,
			UnlockedAt: b.UnlockedAt,
		}
	}
	return out
}
