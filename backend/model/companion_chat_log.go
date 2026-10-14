package model

import "time"

// CompanionChatLog AI 伙伴聊天记录（用于上下文注入 + 训练数据采集）。
type CompanionChatLog struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	UserID    uint      `gorm:"not null;index:idx_comp_chat_user;index:idx_comp_chat_user_hero,priority:1" json:"user_id"`
	HeroID    string    `gorm:"size:32;not null;default:'';index:idx_comp_chat_user_hero,priority:2" json:"hero_id"` // 空串=主伙伴；英雄 slug（arena heroID）
	Role      string    `gorm:"size:16;not null" json:"role"` // user / assistant
	Content   string    `gorm:"type:text;not null" json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

func (CompanionChatLog) TableName() string { return "companion_chat_logs" }
