package achievementbiz

import "backend/rpc/pb/moe"

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
func BadgesFromRPC(items []*moe.AchievementBadgeItem) []BadgeItem {
	if len(items) == 0 {
		return []BadgeItem{}
	}
	out := make([]BadgeItem, 0, len(items))
	for _, b := range items {
		out = append(out, BadgeItem{
			Id: b.Id, Name: b.Name, Description: b.Description, Category: b.Category,
			Rarity: b.Rarity, Condition: b.Condition, RequiredCount: int(b.RequiredCount),
			CurrentCount: int(b.CurrentCount), Progress: b.Progress, IsUnlocked: b.IsUnlocked,
			UnlockedAt: b.UnlockedAt,
		})
	}
	return out
}

// UnlocksFromRPC 新解锁成就 proto → biz DTO。
func UnlocksFromRPC(items []*moe.AchievementUnlock) []UnlockItem {
	if len(items) == 0 {
		return nil
	}
	out := make([]UnlockItem, 0, len(items))
	for _, u := range items {
		out = append(out, UnlockItem{
			BadgeId: u.BadgeId, Name: u.Name, ExpGranted: int(u.ExpGranted),
			LevelUp: u.LevelUp, NewLevel: int(u.NewLevel),
		})
	}
	return out
}
