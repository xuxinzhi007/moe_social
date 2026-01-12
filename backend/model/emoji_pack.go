package model

import (
	"time"
)

// EmojiPack 表情包套餐数据模型
type EmojiPack struct {
	ID           string    `json:"id" gorm:"primaryKey;type:varchar(36)"`
	Name         string    `json:"name" gorm:"type:varchar(100)"`
	Description  string    `json:"description" gorm:"type:text"`
	AuthorID     string    `json:"author_id" gorm:"type:varchar(36)"`
	AuthorName   string    `json:"author_name" gorm:"type:varchar(100)"`
	Category     string    `json:"category" gorm:"type:varchar(50);index"`
	Price        float64   `json:"price" gorm:"type:decimal(10,2)"`
	IsFree       bool      `json:"is_free" gorm:"default:false"`
	CoverImage   string    `json:"cover_image" gorm:"type:varchar(255)"`
	DownloadCount int     `json:"download_count" gorm:"default:0"`
	IsVerified   bool      `json:"is_verified" gorm:"default:false"`
	CreatedAt    time.Time `json:"created_at" gorm:"autoCreateTime"`
}

// TableName 设置表名
func (EmojiPack) TableName() string {
	return "emoji_packs"
}

// UserEmojiPack 用户拥有的表情包关联模型
type UserEmojiPack struct {
	ID         string    `json:"id" gorm:"primaryKey;type:varchar(36)"`
	UserID     string    `json:"user_id" gorm:"type:varchar(36);index"`
	PackID     string    `json:"pack_id" gorm:"type:varchar(36);index"`
	IsFavorited bool     `json:"is_favorited" gorm:"default:false"`
	CreatedAt  time.Time `json:"created_at" gorm:"autoCreateTime"`
}

// TableName 设置表名
func (UserEmojiPack) TableName() string {
	return "user_emoji_packs"
}
