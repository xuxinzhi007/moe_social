package model

import (
	"time"

	"gorm.io/gorm"
)

// Transaction 交易记录模型
type Transaction struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	UserID      uint           `gorm:"index;not null" json:"user_id"`
	Amount      float64        `gorm:"not null" json:"amount"`
	Type        string         `gorm:"size:20;not null" json:"type"` // 充值: recharge, 消费: consume
	Status      string         `gorm:"size:20;default:pending" json:"status"` // pending, success, failed
	Description string         `gorm:"type:text" json:"description"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
