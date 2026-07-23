package model

import "time"

// CompanionChatLog AI 伙伴聊天记录（用于上下文注入 + 训练数据采集）。
type CompanionChatLog struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	UserID    uint      `gorm:"not null;index:idx_comp_chat_user" json:"user_id"`
	Role      string    `gorm:"size:16;not null" json:"role"` // user / assistant
	Content   string    `gorm:"type:text;not null" json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

func (CompanionChatLog) TableName() string { return "companion_chat_logs" }
