package model

import (
	"time"

	"gorm.io/gorm"
)

// Comment 评论模型
type Comment struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	PostID    uint           `gorm:"not null;index" json:"post_id"`     // 帖子ID
	UserID    uint           `gorm:"not null;index" json:"user_id"`     // 用户ID
	Content   string         `gorm:"type:text;not null" json:"content"` // 评论内容
	Likes     int            `gorm:"default:0" json:"likes"`            // 点赞数
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	Post Post `gorm:"foreignKey:PostID" json:"-"` // 帖子关联
	User User `gorm:"foreignKey:UserID" json:"-"` // 用户关联
}
