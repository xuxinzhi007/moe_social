package model

import (
	"time"
)

// UserAvatar 用户虚拟形象数据模型
type UserAvatar struct {
	ID            string    `json:"id" gorm:"primaryKey;type:varchar(36)"`
	UserID        string    `json:"user_id" gorm:"type:varchar(36);index"`
	BaseConfig    string    `json:"base_config" gorm:"type:json"`    // JSON格式存储基础配置
	CurrentOutfit string    `json:"current_outfit" gorm:"type:json"` // JSON格式存储当前装扮
	OwnedOutfits  string    `json:"owned_outfits" gorm:"type:json"`  // JSON格式存储拥有的装扮ID列表
	CreatedAt     time.Time `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt     time.Time `json:"updated_at" gorm:"autoUpdateTime"`
}

// TableName 设置表名
func (UserAvatar) TableName() string {
	return "user_avatars"
}
