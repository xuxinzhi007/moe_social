package model

import (
	"time"

	"gorm.io/gorm"
)

// PostReport 用户举报动态记录
type PostReport struct {
	ID             uint           `gorm:"primarykey" json:"id"`
	PostID         uint           `gorm:"not null;index" json:"post_id"`
	ReporterUserID uint           `gorm:"not null;index" json:"reporter_user_id"`
	Reason         string         `gorm:"type:text" json:"reason"`
	CreatedAt      time.Time      `json:"created_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}
