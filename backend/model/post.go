package model

import (
	"time"

	"gorm.io/gorm"
)

// Post 帖子模型
type Post struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`     // 用户ID
	Content   string         `gorm:"type:text;not null" json:"content"` // 帖子内容
	Images    string         `gorm:"type:text" json:"images"`           // 图片URL列表，JSON格式
	Likes     int            `gorm:"default:0" json:"likes"`            // 点赞数
	Comments  int            `gorm:"default:0" json:"comments"`         // 评论数
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	User       User        `gorm:"foreignKey:UserID" json:"-"`               // 用户关联
	PostTopics []PostTopic `gorm:"foreignKey:PostID" json:"-"`               // 帖子标签关联
	TopicTags  []TopicTag  `gorm:"many2many:post_topics;" json:"topic_tags"` // 多对多关联
}

// TopicTag 话题标签模型
type TopicTag struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	Name      string         `gorm:"not null;unique" json:"name"`    // 标签名称
	Color     string         `gorm:"default:'#007bff'" json:"color"` // 标签颜色
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	PostTopics []PostTopic `gorm:"foreignKey:TopicTagID" json:"-"` // 帖子标签关联
}

// PostTopic 帖子标签关联表
type PostTopic struct {
	PostID     uint           `gorm:"primarykey;not null;index" json:"post_id"`      // 帖子ID，复合主键
	TopicTagID uint           `gorm:"primarykey;not null;index" json:"topic_tag_id"` // 话题标签ID，复合主键
	CreatedAt  time.Time      `json:"created_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	Post     Post     `gorm:"foreignKey:PostID" json:"-"`
	TopicTag TopicTag `gorm:"foreignKey:TopicTagID" json:"-"`
}
