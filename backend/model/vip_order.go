package model

import (
	"time"

	"gorm.io/gorm"
)

// VipOrder VIP订单模型
type VipOrder struct {
	ID         uint           `gorm:"primarykey" json:"id"`
	UserID     uint           `gorm:"not null;index" json:"user_id"`        // 用户ID
	PlanID     uint           `gorm:"not null;index" json:"plan_id"`        // 套餐ID
	OrderNo    string         `gorm:"size:50;uniqueIndex;not null" json:"order_no"` // 订单号
	Amount     float64        `gorm:"not null" json:"amount"`               // 订单金额
	Status     string         `gorm:"size:20;not null" json:"status"`        // 订单状态：pending, paid, cancelled
	PayMethod  string         `gorm:"size:20" json:"pay_method"`            // 支付方式：wechat, alipay, etc.
	CreatedAt  time.Time      `json:"created_at"`
	UpdatedAt  time.Time      `json:"updated_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	User       User       `gorm:"foreignKey:UserID" json:"-"`               // 用户关联
	Plan       VipPlan    `gorm:"foreignKey:PlanID" json:"plan"`            // 套餐关联
}
