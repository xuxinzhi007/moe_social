package logic

import (
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// LikedTargetIDSet 返回 targetIDs 中已被 userID 点赞的 ID（GORM 自动排除软删的 likes）。
func LikedTargetIDSet(db *gorm.DB, userID uint, targetType string, targetIDs []uint) map[uint]bool {
	out := make(map[uint]bool)
	if userID == 0 || len(targetIDs) == 0 {
		return out
	}
	var found []uint
	if err := db.Model(&model.Like{}).
		Where("user_id = ? AND target_type = ? AND target_id IN ?", userID, targetType, targetIDs).
		Pluck("target_id", &found).Error; err != nil {
		return out
	}
	for _, id := range found {
		out[id] = true
	}
	return out
}

// moderationVisibleScope 列表可见：非 rejected；pending 仅作者可见
func moderationVisibleScope(viewerUserID uint) func(db *gorm.DB) *gorm.DB {
	return func(db *gorm.DB) *gorm.DB {
		return db.Where("(moderation_status IS NULL OR moderation_status <> ?)", "rejected").
			Where("(moderation_status IS NULL OR moderation_status = '' OR moderation_status = 'ok') OR (moderation_status = 'pending' AND user_id = ?)", viewerUserID)
	}
}

func moderationStatusOrDefault(s string) string {
	if strings.TrimSpace(s) == "" {
		return "ok"
	}
	return s
}
