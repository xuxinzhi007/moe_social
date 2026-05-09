package model

import (
	"time"

	"gorm.io/gorm"
)

type UserMemory struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	UserID      uint           `gorm:"not null;index:idx_user_key,unique;index:idx_user_updated,priority:1;index:idx_user_memory_type,priority:1" json:"user_id"`
	Key         string         `gorm:"size:100;index:idx_user_key,unique" json:"key"`
	Value       string         `gorm:"type:text" json:"value"`
	MemoryType  string         `gorm:"size:32;default:fact;index:idx_user_memory_type,priority:2" json:"memory_type"`
	Confidence  float64        `gorm:"default:0.6" json:"confidence"`
	Source      string         `gorm:"size:128;default:unknown" json:"source"`
	SourceMsgID string         `gorm:"size:64;index" json:"source_msg_id"`
	SessionID   string         `gorm:"size:64;index" json:"session_id"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `gorm:"index:idx_user_updated,priority:2" json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`

	User User `gorm:"foreignKey:UserID" json:"-"`
}

type UserMemoryFeedback struct {
	ID           uint      `gorm:"primarykey" json:"id"`
	UserID       uint      `gorm:"not null;index" json:"user_id"`
	Key          string    `gorm:"size:100;not null;index" json:"key"`
	FeedbackType string    `gorm:"size:20;not null;index" json:"feedback_type"`
	OldValue     string    `gorm:"type:text" json:"old_value"`
	NewValue     string    `gorm:"type:text" json:"new_value"`
	Reason       string    `gorm:"size:255" json:"reason"`
	CreatedAt    time.Time `json:"created_at"`
}

// UserMemoryProfileCache 是后端聚合后的画像缓存，供前端直接展示，避免每次请求实时重算。
type UserMemoryProfileCache struct {
	ID         uint      `gorm:"primarykey" json:"id"`
	UserID     uint      `gorm:"not null;index:idx_user_profile_type,priority:1;index" json:"user_id"`
	MemoryType string    `gorm:"size:32;not null;index:idx_user_profile_type,priority:2" json:"memory_type"`
	Summary    string    `gorm:"type:text" json:"summary"`
	ItemCount  int       `gorm:"not null;default:0" json:"item_count"`
	Confidence float64   `gorm:"not null;default:0.6" json:"confidence"`
	UpdatedAt  time.Time `gorm:"index" json:"updated_at"`
	CreatedAt  time.Time `json:"created_at"`
}
