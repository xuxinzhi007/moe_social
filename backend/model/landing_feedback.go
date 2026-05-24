package model

import "time"

// LandingFeedback 官网等产品落地页提交的用户反馈。
type LandingFeedback struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	Email     string    `gorm:"size:120;index" json:"email"`
	Category  string    `gorm:"size:32;not null;default:other;index" json:"category"`
	Content   string    `gorm:"type:text;not null" json:"content"`
	Source    string    `gorm:"size:64;not null;default:official-site" json:"source"`
	ClientIP  string    `gorm:"size:64" json:"client_ip"`
	UserAgent string    `gorm:"size:255" json:"user_agent"`
	CreatedAt time.Time `gorm:"index" json:"created_at"`
}
