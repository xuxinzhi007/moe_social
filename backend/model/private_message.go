package model

import (
	"time"
)

// PrivateMessage 一对一私信持久化（与 WS 实时通道配合；过期后物理删除）。
type PrivateMessage struct {
	ID            uint      `gorm:"primarykey" json:"id"`
	SenderID      uint      `gorm:"not null;index:idx_pm_conv,priority:1" json:"sender_id"`
	ReceiverID    uint      `gorm:"not null;index:idx_pm_conv,priority:2" json:"receiver_id"`
	Body       string `gorm:"type:text;not null" json:"body"`
	ImagePaths string `gorm:"type:text" json:"image_paths"` // JSON 数组字符串，如 ["a.png"]，与 /api/images/{name} 中 name 一致
	RetentionDays uint8    `gorm:"not null" json:"retention_days"` // 写入时快照，便于审计与以后会员策略变更
	ExpiresAt     time.Time `gorm:"not null;index" json:"expires_at"`
	CreatedAt     time.Time `gorm:"not null;index:idx_pm_conv,priority:3" json:"created_at"`
}

func (PrivateMessage) TableName() string {
	return "private_messages"
}
