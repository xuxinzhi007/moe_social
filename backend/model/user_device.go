package model

import (
	"time"

	"gorm.io/gorm"
)

// UserDevice 用户登录设备登记（与对话记忆 user_memories 分离）。
type UserDevice struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	UserID      uint           `gorm:"not null;uniqueIndex:idx_user_device,priority:1" json:"user_id"`
	DeviceID    string         `gorm:"size:64;not null;uniqueIndex:idx_user_device,priority:2" json:"device_id"`
	Platform    string         `gorm:"size:32" json:"platform"`
	OSVersion   string         `gorm:"size:64" json:"os_version"`
	AppVersion  string         `gorm:"size:64" json:"app_version"`
	DeviceName  string         `gorm:"size:128" json:"device_name"`
	PayloadJSON string         `gorm:"type:text" json:"payload_json"`
	LastSeenAt  time.Time      `gorm:"index" json:"last_seen_at"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `gorm:"index" json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
