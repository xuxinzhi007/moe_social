package model

import (
	"time"

	"gorm.io/gorm"
)

// GiftPurchaseOrder 用心意（余额）购买礼物进入背包的订单记录
type GiftPurchaseOrder struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	UserID      uint           `gorm:"not null;index" json:"user_id"`
	OrderNo     string         `gorm:"size:64;uniqueIndex;not null" json:"order_no"`
	GiftID      uint           `gorm:"not null;index" json:"gift_id"`
	GiftName    string         `gorm:"size:128;not null" json:"gift_name"`
	Quantity    int            `gorm:"not null" json:"quantity"`
	UnitPrice   float64        `gorm:"not null" json:"unit_price"`
	TotalAmount float64        `gorm:"not null" json:"total_amount"`
	PayMethod   string         `gorm:"size:20;not null;default:wallet" json:"pay_method"`
	Status      string         `gorm:"size:20;not null;default:paid" json:"status"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
