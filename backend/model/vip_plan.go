package model

import (
	"time"

	"gorm.io/gorm"
)

// VipPlan VIP套餐模型
type VipPlan struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	Name      string         `gorm:"size:50;not null" json:"name"`      // 套餐名称
	Price     float64        `gorm:"not null" json:"price"`            // 价格
	Duration  int            `gorm:"not null" json:"duration"`         // 有效期（天数）
	Features  string         `gorm:"type:text" json:"features"`        // 套餐特色，JSON格式
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}
