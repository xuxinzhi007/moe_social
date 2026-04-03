package achievement

import (
	"time"
	"unicode/utf8"

	"backend/model"

	"gorm.io/gorm"
)

// RequiredCount 与 lib/models/achievement_badge.dart defaultBadges 一致
var RequiredCount = map[string]int{
	"first_post":       1,
	"post_master":      100,
	"like_magnet":      100,
	"social_butterfly": 1000,
	"generous_giver":   50,
	"gift_tycoon":      1000,
	"emotion_expert":   10,
	"early_bird":       7,
	"night_owl":        7,
	"loyal_user":       30,
	"vip_member":       1,
	"trendsetter":      100,
	"photographer":     50,
	"influencer":       1000,
	"creative_genius":  10,
	"storyteller":      10,
}

// Bump 增加进度；若本次 newly 解锁则返回该 badge_id
func Bump(db *gorm.DB, userID uint, badgeID string, delta int) []string {
	if delta <= 0 {
		return nil
	}
	req, ok := RequiredCount[badgeID]
	if !ok || req <= 0 {
		return nil
	}

	var row model.UserBadgeProgress
	err := db.Where("user_id = ? AND badge_id = ?", userID, badgeID).First(&row).Error
	if err == gorm.ErrRecordNotFound {
		row = model.UserBadgeProgress{UserID: userID, BadgeID: badgeID, CurrentCount: 0}
	} else if err != nil {
		return nil
	}

	if row.UnlockedAt != nil {
		return nil
	}

	row.CurrentCount += delta
	if row.CurrentCount > req {
		row.CurrentCount = req
	}

	now := time.Now()
	unlocked := false
	if row.CurrentCount >= req {
		row.UnlockedAt = &now
		unlocked = true
	}

	if err := db.Save(&row).Error; err != nil {
		return nil
	}
	if unlocked {
		return []string{badgeID}
	}
	return nil
}

// ReachAtLeast 将进度至少设为 floor（不超过 required），用于单帖百赞、千粉等
func ReachAtLeast(db *gorm.DB, userID uint, badgeID string, floor int) []string {
	req, ok := RequiredCount[badgeID]
	if !ok || req <= 0 || floor <= 0 {
		return nil
	}

	var row model.UserBadgeProgress
	err := db.Where("user_id = ? AND badge_id = ?", userID, badgeID).First(&row).Error
	if err == gorm.ErrRecordNotFound {
		row = model.UserBadgeProgress{UserID: userID, BadgeID: badgeID, CurrentCount: 0}
	} else if err != nil {
		return nil
	}

	if row.UnlockedAt != nil {
		return nil
	}

	if floor > req {
		floor = req
	}
	if row.CurrentCount < floor {
		row.CurrentCount = floor
	}

	now := time.Now()
	unlocked := false
	if row.CurrentCount >= req {
		row.UnlockedAt = &now
		unlocked = true
	}

	if err := db.Save(&row).Error; err != nil {
		return nil
	}
	if unlocked {
		return []string{badgeID}
	}
	return nil
}

// ApplyPostCreated 发帖后成就（使用 t 的本地时区小时，与客户端 DateTime.now() 行为尽量接近）
func ApplyPostCreated(db *gorm.DB, userID uint, content string, imageCount int, t time.Time) []string {
	var out []string
	out = append(out, Bump(db, userID, "first_post", 1)...)
	out = append(out, Bump(db, userID, "post_master", 1)...)
	if imageCount > 0 {
		out = append(out, Bump(db, userID, "photographer", imageCount)...)
	}
	if utf8.RuneCountInString(content) >= 500 {
		out = append(out, Bump(db, userID, "storyteller", 1)...)
	}
	h := t.Hour()
	if h < 8 {
		out = append(out, Bump(db, userID, "early_bird", 1)...)
	}
	if h >= 23 {
		out = append(out, Bump(db, userID, "night_owl", 1)...)
	}
	return dedupe(out)
}

func ApplyCommentCreated(db *gorm.DB, userID uint) []string {
	return Bump(db, userID, "social_butterfly", 1)
}

func ApplyCheckIn(db *gorm.DB, userID uint) []string {
	return Bump(db, userID, "loyal_user", 1)
}

func ApplyVipMember(db *gorm.DB, userID uint) []string {
	return Bump(db, userID, "vip_member", 1)
}

func ApplyPostLikedAsAuthor(db *gorm.DB, authorUserID uint, likesAfter int) []string {
	if likesAfter < 100 {
		return nil
	}
	return ReachAtLeast(db, authorUserID, "like_magnet", 100)
}

func ApplyFollowerMilestone(db *gorm.DB, followedUserID uint, followerCount int64) []string {
	if followerCount < 1000 {
		return nil
	}
	return ReachAtLeast(db, followedUserID, "influencer", 1000)
}

func dedupe(in []string) []string {
	seen := make(map[string]struct{}, len(in))
	var out []string
	for _, id := range in {
		if id == "" {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	return out
}
