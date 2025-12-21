package model

import (
	"time"

	"gorm.io/gorm"
)

// Post 帖子模型
type Post struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`        // 用户ID
	Content   string         `gorm:"type:text;not null" json:"content"`    // 帖子内容
	Images    string         `gorm:"type:text" json:"images"`              // 图片URL列表，JSON格式
	Likes     int            `gorm:"default:0" json:"likes"`               // 点赞数
	Comments  int            `gorm:"default:0" json:"comments"`            // 评论数
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	User      User       `gorm:"foreignKey:UserID" json:"-"`              // 用户关联
	PostLikes []PostLike `gorm:"foreignKey:PostID" json:"-"`               // 点赞关联
}

// PostLike 帖子点赞关联表
type PostLike struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	PostID    uint           `gorm:"not null;index" json:"post_id"`       // 帖子ID
	UserID    uint           `gorm:"not null;index" json:"user_id"`       // 用户ID
	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	Post Post `gorm:"foreignKey:PostID" json:"-"`
	User User `gorm:"foreignKey:UserID" json:"-"`
}

