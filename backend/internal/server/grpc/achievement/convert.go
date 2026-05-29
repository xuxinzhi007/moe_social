package achievementgrpc

import (
	achievementv1 "backend/api/achievement/v1"
	moerpc "backend/rpc/pb/moe"
)

func badgesToProto(rows []*moerpc.AchievementBadgeItem) []*achievementv1.AchievementBadgeItem {
	out := make([]*achievementv1.AchievementBadgeItem, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &achievementv1.AchievementBadgeItem{
			Id: row.GetId(), Name: row.GetName(), Description: row.GetDescription(),
			Category: row.GetCategory(), Rarity: row.GetRarity(), Condition: row.GetCondition(),
			RequiredCount: row.GetRequiredCount(), CurrentCount: row.GetCurrentCount(),
			Progress: row.GetProgress(), IsUnlocked: row.GetIsUnlocked(),
			UnlockedAt: row.GetUnlockedAt(),
		})
	}
	return out
}

func summaryToProto(in *moerpc.AchievementSummary) *achievementv1.AchievementSummary {
	if in == nil {
		return nil
	}
	return &achievementv1.AchievementSummary{
		TotalBadges: in.GetTotalBadges(), UnlockedBadges: in.GetUnlockedBadges(),
		CompletionPercentage: in.GetCompletionPercentage(),
	}
}

func achievementUnlocksToProto(rows []*moerpc.AchievementUnlock) []*achievementv1.AchievementUnlock {
	out := make([]*achievementv1.AchievementUnlock, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &achievementv1.AchievementUnlock{
			BadgeId: row.GetBadgeId(), Name: row.GetName(), ExpGranted: row.GetExpGranted(),
			LevelUp: row.GetLevelUp(), NewLevel: row.GetNewLevel(),
		})
	}
	return out
}
