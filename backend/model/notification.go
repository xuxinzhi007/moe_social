package model

import (
	"time"

	"gorm.io/gorm"
)

// Notification 通知模型
type Notification struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`   // 接收通知的用户ID (被评论/点赞的人)
	SenderID  uint           `gorm:"not null;index" json:"sender_id"` // 发送通知的用户ID (评论/点赞的人)
	Type      int            `gorm:"not null" json:"type"`            // 1:点赞帖子 2:评论 3:关注 4:系统 5:点赞评论 6:私信
	PostID    uint           `gorm:"index" json:"post_id"`            // 相关帖子ID
	Content   string         `gorm:"type:text" json:"content"`        // 通知内容 (评论内容摘要)
	IsRead    bool           `gorm:"default:false" json:"is_read"`    // 是否已读
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联
	Sender User `gorm:"foreignKey:SenderID" json:"sender"`
	Post   Post `gorm:"foreignKey:PostID" json:"post"`
}
