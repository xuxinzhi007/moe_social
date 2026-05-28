package handlerutil

import (
	"backend/api/internal/types"
	achievementbiz "backend/internal/biz/achievement"
	"backend/rpc/pb/moe"
)

// UnlocksFromRPC 新解锁成就 proto → API types（handler 层，替代 logic/achievement）。
func UnlocksFromRPC(items []*moe.AchievementUnlock) []types.AchievementUnlock {
	bizItems := achievementbiz.UnlocksFromRPC(items)
	if len(bizItems) == 0 {
		return nil
	}
	out := make([]types.AchievementUnlock, len(bizItems))
	for i, u := range bizItems {
		out[i] = types.AchievementUnlock{
			BadgeId: u.BadgeId, Name: u.Name, ExpGranted: u.ExpGranted,
			LevelUp: u.LevelUp, NewLevel: u.NewLevel,
		}
	}
	return out
}
