package achievement

import (
	checkinv1 "backend/api/checkin/v1"
	commentv1 "backend/api/comment/v1"
	giftv1 "backend/api/gift/v1"
	postv1 "backend/api/post/v1"
)

// UnlocksToPostV1 converts unlock results to post.v1 messages.
func UnlocksToPostV1(unlocks []UnlockResult) []*postv1.AchievementUnlock {
	if len(unlocks) == 0 {
		return nil
	}
	out := make([]*postv1.AchievementUnlock, 0, len(unlocks))
	for _, u := range unlocks {
		out = append(out, &postv1.AchievementUnlock{
			BadgeId: u.BadgeID, Name: u.Name, ExpGranted: int32(u.ExpGranted),
			LevelUp: u.LevelUp, NewLevel: int32(u.NewLevel),
		})
	}
	return out
}

// UnlocksToGiftV1 converts unlock results to gift.v1 messages.
func UnlocksToGiftV1(unlocks []UnlockResult) []*giftv1.AchievementUnlock {
	if len(unlocks) == 0 {
		return nil
	}
	out := make([]*giftv1.AchievementUnlock, 0, len(unlocks))
	for _, u := range unlocks {
		out = append(out, &giftv1.AchievementUnlock{
			BadgeId: u.BadgeID, Name: u.Name, ExpGranted: int32(u.ExpGranted),
			LevelUp: u.LevelUp, NewLevel: int32(u.NewLevel),
		})
	}
	return out
}

// UnlocksToCommentV1 converts unlock results to comment.v1 messages.
func UnlocksToCommentV1(unlocks []UnlockResult) []*commentv1.AchievementUnlock {
	if len(unlocks) == 0 {
		return nil
	}
	out := make([]*commentv1.AchievementUnlock, 0, len(unlocks))
	for _, u := range unlocks {
		out = append(out, &commentv1.AchievementUnlock{
			BadgeId: u.BadgeID, Name: u.Name, ExpGranted: int32(u.ExpGranted),
			LevelUp: u.LevelUp, NewLevel: int32(u.NewLevel),
		})
	}
	return out
}

// UnlocksToCheckinV1 converts unlock results to checkin.v1 messages.
func UnlocksToCheckinV1(unlocks []UnlockResult) []*checkinv1.AchievementUnlock {
	if len(unlocks) == 0 {
		return nil
	}
	out := make([]*checkinv1.AchievementUnlock, 0, len(unlocks))
	for _, u := range unlocks {
		out = append(out, &checkinv1.AchievementUnlock{
			BadgeId: u.BadgeID, Name: u.Name, ExpGranted: int32(u.ExpGranted),
			LevelUp: u.LevelUp, NewLevel: int32(u.NewLevel),
		})
	}
	return out
}
