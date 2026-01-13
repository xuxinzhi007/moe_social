package model

import (
	"time"

	"gorm.io/gorm"
)

// Like 统一点赞模型
type Like struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	UserID      uint           `gorm:"not null;index" json:"user_id"`
	TargetID    uint           `gorm:"not null;index" json:"target_id"` // 点赞对象ID（帖子/评论）
	TargetType  string         `gorm:"size:20;not null;index" json:"target_type"` // post/comment
	CreatedAt   time.Time      `json:"created_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	User        User           `gorm:"foreignKey:UserID" json:"-"`
}
