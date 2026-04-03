package model

import (
	"time"

	"gorm.io/gorm"
)

// UserBadgeProgress 用户成就进度（与 Flutter AchievementBadge.defaultBadges 对齐）
type UserBadgeProgress struct {
	ID           uint           `gorm:"primarykey" json:"id"`
	UserID       uint           `gorm:"not null;uniqueIndex:idx_user_badge" json:"user_id"`
	BadgeID      string         `gorm:"size:64;not null;uniqueIndex:idx_user_badge" json:"badge_id"`
	CurrentCount int            `gorm:"not null;default:0" json:"current_count"`
	UnlockedAt   *time.Time     `json:"unlocked_at,omitempty"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}
