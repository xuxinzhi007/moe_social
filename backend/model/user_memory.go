package model

import (
	"time"

	"gorm.io/gorm"
)

type UserMemory struct {
	ID         uint           `gorm:"primarykey" json:"id"`
	UserID     uint           `gorm:"not null;index:idx_user_key,unique" json:"user_id"`
	Key        string         `gorm:"size:100;index:idx_user_key,unique" json:"key"`
	Value      string         `gorm:"type:text" json:"value"`
	MemoryType string         `gorm:"size:32;default:fact;index" json:"memory_type"`
	Confidence float64        `gorm:"default:0.6" json:"confidence"`
	Source     string         `gorm:"size:128;default:unknown" json:"source"`
	CreatedAt  time.Time      `json:"created_at"`
	UpdatedAt  time.Time      `json:"updated_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`

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
