package model

import "time"

// CompanionMemory AI 伙伴的持久记忆（对话摘要/里程碑/偏好/事实）。
type CompanionMemory struct {
	ID              uint       `gorm:"primarykey" json:"id"`
	UserID          uint       `gorm:"not null;index:idx_comp_mem_user" json:"user_id"`
	MemoryType      string     `gorm:"size:16;not null;index:idx_comp_mem_type" json:"memory_type"` // conversation / milestone / preference / fact
	Content         string     `gorm:"type:text;not null" json:"content"`
	Importance      int        `gorm:"not null;default:0" json:"importance"` // 0=7天 / 1=30天 / 2=永久
	Pinned          bool       `gorm:"not null;default:false;index:idx_comp_mem_pinned" json:"pinned"`
	SourceChatLogID uint       `gorm:"default:0" json:"source_chat_log_id"`
	ExpiresAt       *time.Time `json:"expires_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

func (CompanionMemory) TableName() string { return "companion_memories" }
