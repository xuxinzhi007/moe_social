package model

import (
	"time"
)

// AvatarOutfit 虚拟形象装扮物品数据模型
type AvatarOutfit struct {
	ID          string    `json:"id" gorm:"primaryKey;type:varchar(36)"`
	Name        string    `json:"name" gorm:"type:varchar(100)"`
	Description string    `json:"description" gorm:"type:text"`
	Category    string    `json:"category" gorm:"type:varchar(50);index"` // 服饰、发型、配饰等
	Style       string    `json:"style" gorm:"type:varchar(50);index"`    // 可爱风、御姐风等
	Price       float64   `json:"price" gorm:"type:decimal(10,2)"`
	IsFree      bool      `json:"is_free" gorm:"default:false"`
	ImageURL    string    `json:"image_url" gorm:"type:varchar(255)"`
	Parts       string    `json:"parts" gorm:"type:json"` // JSON格式存储装扮部件列表
	CreatedAt   time.Time `json:"created_at" gorm:"autoCreateTime"`
}

// TableName 设置表名
func (AvatarOutfit) TableName() string {
	return "avatar_outfits"
}
