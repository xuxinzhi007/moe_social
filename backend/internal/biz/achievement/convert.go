package achievementbiz

import (
	achievementv1 "backend/api/achievement/v1"
)

// BadgeItem 成就徽章（compat 层映射为 types.AchievementBadgeItem）。
type BadgeItem struct {
	Id            string
	Name          string
	Description   string
	Category      string
	Rarity        string
	Condition     string
	RequiredCount int
	CurrentCount  int
	Progress      float64
	IsUnlocked    bool
	UnlockedAt    string
}

// UnlockItem 新解锁成就（compat 层映射为 types.AchievementUnlock）。
type UnlockItem struct {
	BadgeId    string
	Name       string
	ExpGranted int
	LevelUp    bool
	NewLevel   int
}

// BadgesFromRPC 成就徽章列表 proto → biz DTO。
func BadgesFromRPC(items []*achievementv1.AchievementBadgeItem) []BadgeItem {
	if len(items) == 0 {
		return []BadgeItem{}
	}
	out := make([]BadgeItem, 0, len(items))
	for _, b := range items {
		if b == nil {
			continue
		}
		out = append(out, BadgeItem{
			Id: b.GetId(), Name: b.GetName(), Description: b.GetDescription(), Category: b.GetCategory(),
			Rarity: b.GetRarity(), Condition: b.GetCondition(), RequiredCount: int(b.GetRequiredCount()),
			CurrentCount: int(b.GetCurrentCount()), Progress: b.GetProgress(), IsUnlocked: b.GetIsUnlocked(),
			UnlockedAt: b.GetUnlockedAt(),
		})
	}
	return out
}

// UnlocksFromRPC 新解锁成就 proto → biz DTO。
func UnlocksFromRPC(items []*achievementv1.AchievementUnlock) []UnlockItem {
	if len(items) == 0 {
		return nil
	}
	out := make([]UnlockItem, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, UnlockItem{
			BadgeId: u.GetBadgeId(), Name: u.GetName(), ExpGranted: int(u.GetExpGranted()),
			LevelUp: u.GetLevelUp(), NewLevel: int(u.GetNewLevel()),
		})
	}
	return out
}
