package achievement

import (
	"backend/rpc/pb/moe"
)

// UnlocksToProto converts unlock results to RPC messages.
func UnlocksToProto(unlocks []UnlockResult) []*moe.AchievementUnlock {
	if len(unlocks) == 0 {
		return nil
	}
	out := make([]*moe.AchievementUnlock, 0, len(unlocks))
	for _, u := range unlocks {
		out = append(out, &moe.AchievementUnlock{
			BadgeId:    u.BadgeID,
			Name:       u.Name,
			ExpGranted: int32(u.ExpGranted),
			LevelUp:    u.LevelUp,
			NewLevel:   int32(u.NewLevel),
		})
	}
	return out
}

// BadgesToProto converts badge DTOs to RPC messages.
func BadgesToProto(badges []BadgeDTO) []*moe.AchievementBadgeItem {
	out := make([]*moe.AchievementBadgeItem, 0, len(badges))
	for _, b := range badges {
		out = append(out, &moe.AchievementBadgeItem{
			Id:            b.ID,
			Name:          b.Name,
			Description:   b.Description,
			Category:      b.Category,
			Rarity:        b.Rarity,
			Condition:     b.Condition,
			RequiredCount: int32(b.RequiredCount),
			CurrentCount:  int32(b.CurrentCount),
			Progress:      b.Progress,
			IsUnlocked:    b.IsUnlocked,
			UnlockedAt:    b.UnlockedAt,
		})
	}
	return out
}
