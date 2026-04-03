package logic

import (
	"strings"

	"gorm.io/gorm"
)

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
