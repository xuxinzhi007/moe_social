package model

import (
	"time"
)

// Emoji 单个表情包数据模型
type Emoji struct {
	ID         string    `json:"id" gorm:"primaryKey;type:varchar(36)"`
	PackID     string    `json:"pack_id" gorm:"type:varchar(36);index"` // 所属表情包ID
	ImageURL   string    `json:"image_url" gorm:"type:varchar(255)"`
	Tags       string    `json:"tags" gorm:"type:json"` // JSON格式存储标签列表
	IsAnimated bool      `json:"is_animated" gorm:"default:false"`
	Size       int       `json:"size" gorm:"type:int"` // 文件大小（字节）
	CreatedAt  time.Time `json:"created_at" gorm:"autoCreateTime"`
}

// TableName 设置表名
func (Emoji) TableName() string {
	return "emojis"
}
