package achievement

import (
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func badgesFromRPC(items []*super.AchievementBadgeItem) []types.AchievementBadgeItem {
	if len(items) == 0 {
		return []types.AchievementBadgeItem{}
	}
	out := make([]types.AchievementBadgeItem, 0, len(items))
	for _, b := range items {
		out = append(out, types.AchievementBadgeItem{
			Id:            b.Id,
			Name:          b.Name,
			Description:   b.Description,
			Category:      b.Category,
			Rarity:        b.Rarity,
			Condition:     b.Condition,
			RequiredCount: int(b.RequiredCount),
			CurrentCount:  int(b.CurrentCount),
			Progress:      b.Progress,
			IsUnlocked:    b.IsUnlocked,
			UnlockedAt:    b.UnlockedAt,
		})
	}
	return out
}

// UnlocksFromRPC exports unlock conversion for other API logic packages.
func UnlocksFromRPC(items []*super.AchievementUnlock) []types.AchievementUnlock {
	return unlocksFromRPC(items)
}

func unlocksFromRPC(items []*super.AchievementUnlock) []types.AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]types.AchievementUnlock, 0, len(items))
	for _, u := range items {
		out = append(out, types.AchievementUnlock{
			BadgeId:    u.BadgeId,
			Name:       u.Name,
			ExpGranted: int(u.ExpGranted),
			LevelUp:    u.LevelUp,
			NewLevel:   int(u.NewLevel),
		})
	}
	return out
}
