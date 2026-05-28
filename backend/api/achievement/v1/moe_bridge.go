package achievementv1

import "backend/rpc/pb/moe"

func GetUserAchievementsRequestFromMoe(in *moe.GetUserAchievementsReq) *GetUserAchievementsRequest {
	if in == nil {
		return &GetUserAchievementsRequest{}
	}
	return &GetUserAchievementsRequest{UserId: in.GetUserId()}
}

func GetUserAchievementsReplyToMoe(out *GetUserAchievementsReply) *moe.GetUserAchievementsResp {
	if out == nil {
		return &moe.GetUserAchievementsResp{}
	}
	return &moe.GetUserAchievementsResp{Badges: BadgesToMoe(out.GetBadges())}
}

func GetUserUnlockedAchievementsRequestFromMoe(in *moe.GetUserUnlockedAchievementsReq) *GetUserUnlockedAchievementsRequest {
	if in == nil {
		return &GetUserUnlockedAchievementsRequest{}
	}
	return &GetUserUnlockedAchievementsRequest{UserId: in.GetUserId()}
}

func GetUserUnlockedAchievementsReplyToMoe(out *GetUserUnlockedAchievementsReply) *moe.GetUserUnlockedAchievementsResp {
	if out == nil {
		return &moe.GetUserUnlockedAchievementsResp{}
	}
	return &moe.GetUserUnlockedAchievementsResp{Badges: BadgesToMoe(out.GetBadges())}
}

func GetUserAchievementSummaryRequestFromMoe(in *moe.GetUserAchievementSummaryReq) *GetUserAchievementSummaryRequest {
	if in == nil {
		return &GetUserAchievementSummaryRequest{}
	}
	return &GetUserAchievementSummaryRequest{UserId: in.GetUserId()}
}

func GetUserAchievementSummaryReplyToMoe(out *GetUserAchievementSummaryReply) *moe.GetUserAchievementSummaryResp {
	if out == nil {
		return &moe.GetUserAchievementSummaryResp{}
	}
	if s := out.GetSummary(); s != nil {
		return &moe.GetUserAchievementSummaryResp{Summary: &moe.AchievementSummary{
			TotalBadges:            s.GetTotalBadges(),
			UnlockedBadges:         s.GetUnlockedBadges(),
			CompletionPercentage:   s.GetCompletionPercentage(),
		}}
	}
	return &moe.GetUserAchievementSummaryResp{}
}

func EnsureUserAchievementsRequestFromMoe(in *moe.EnsureUserAchievementsReq) *EnsureUserAchievementsRequest {
	if in == nil {
		return &EnsureUserAchievementsRequest{}
	}
	return &EnsureUserAchievementsRequest{UserId: in.GetUserId()}
}

func EnsureUserAchievementsReplyToMoe(out *EnsureUserAchievementsReply) *moe.EnsureUserAchievementsResp {
	if out == nil {
		return &moe.EnsureUserAchievementsResp{}
	}
	return &moe.EnsureUserAchievementsResp{NewAchievements: UnlocksToMoe(out.GetNewAchievements())}
}

func BadgesFromMoe(items []*moe.AchievementBadgeItem) []*AchievementBadgeItem {
	if len(items) == 0 {
		return nil
	}
	out := make([]*AchievementBadgeItem, 0, len(items))
	for _, b := range items {
		if b == nil {
			continue
		}
		out = append(out, &AchievementBadgeItem{
			Id: b.GetId(), Name: b.GetName(), Description: b.GetDescription(),
			Category: b.GetCategory(), Rarity: b.GetRarity(), Condition: b.GetCondition(),
			RequiredCount: b.GetRequiredCount(), CurrentCount: b.GetCurrentCount(),
			Progress: b.GetProgress(), IsUnlocked: b.GetIsUnlocked(), UnlockedAt: b.GetUnlockedAt(),
		})
	}
	return out
}

func BadgesToMoe(items []*AchievementBadgeItem) []*moe.AchievementBadgeItem {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.AchievementBadgeItem, 0, len(items))
	for _, b := range items {
		if b == nil {
			continue
		}
		out = append(out, &moe.AchievementBadgeItem{
			Id: b.GetId(), Name: b.GetName(), Description: b.GetDescription(),
			Category: b.GetCategory(), Rarity: b.GetRarity(), Condition: b.GetCondition(),
			RequiredCount: b.GetRequiredCount(), CurrentCount: b.GetCurrentCount(),
			Progress: b.GetProgress(), IsUnlocked: b.GetIsUnlocked(), UnlockedAt: b.GetUnlockedAt(),
		})
	}
	return out
}

func UnlocksFromMoe(items []*moe.AchievementUnlock) []*AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]*AchievementUnlock, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, &AchievementUnlock{
			BadgeId: u.GetBadgeId(), Name: u.GetName(), ExpGranted: u.GetExpGranted(),
			LevelUp: u.GetLevelUp(), NewLevel: u.GetNewLevel(),
		})
	}
	return out
}

func UnlocksToMoe(items []*AchievementUnlock) []*moe.AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.AchievementUnlock, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, &moe.AchievementUnlock{
			BadgeId: u.GetBadgeId(), Name: u.GetName(), ExpGranted: u.GetExpGranted(),
			LevelUp: u.GetLevelUp(), NewLevel: u.GetNewLevel(),
		})
	}
	return out
}
