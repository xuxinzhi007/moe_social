package model

import (
	"time"

	"gorm.io/gorm"
)

const (
	AnnouncementStatusDraft     = "draft"
	AnnouncementStatusPublished = "published"
)

// AdminAnnouncement 运维后台公告。
type AdminAnnouncement struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	Title       string         `gorm:"size:200;not null" json:"title"`
	Content     string         `gorm:"type:text" json:"content"`
	Status      string         `gorm:"size:20;not null;default:draft;index" json:"status"`
	PublishedAt *time.Time     `json:"published_at,omitempty"`
	CreatedBy   uint           `gorm:"not null;index" json:"created_by"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
