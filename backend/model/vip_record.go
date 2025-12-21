package model

import (
	"time"

	"gorm.io/gorm"
)

// VipRecord VIP记录模型
type VipRecord struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`        // 用户ID
	PlanID    uint           `gorm:"not null;index" json:"plan_id"`        // 套餐ID
	IsActive  bool           `gorm:"default:false" json:"is_active"`       // 是否激活
	StartAt   time.Time      `json:"start_at"`                              // 开始时间
	EndAt     time.Time      `json:"end_at"`                                // 结束时间
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	User      User       `gorm:"foreignKey:UserID" json:"-"`               // 用户关联
	Plan      VipPlan    `gorm:"foreignKey:PlanID" json:"plan"`            // 套餐关联
}
