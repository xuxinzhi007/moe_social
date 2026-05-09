package model

import (
	"time"
)

// Gift 礼物模型
type Gift struct {
	ID          uint      `gorm:"primarykey" json:"id"`
	Name        string    `gorm:"size:50;not null" json:"name"`
	Price       int       `gorm:"not null" json:"price"`
	Icon        string    `gorm:"size:255" json:"icon"`
	Description string    `gorm:"size:255" json:"description"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// GiftRecord 礼物赠送记录
type GiftRecord struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	FromUserID uint      `gorm:"not null;index" json:"from_user_id"`
	ToUserID   uint      `gorm:"not null;index" json:"to_user_id"`
	GiftID     uint      `gorm:"not null;index" json:"gift_id"`
	Quantity   int       `gorm:"not null;default:1" json:"quantity"`
	Message    string    `gorm:"size:255" json:"message"`
	CreatedAt  time.Time `json:"created_at"`

	// 关联关系
	FromUser User `gorm:"foreignKey:FromUserID" json:"-"`
	ToUser   User `gorm:"foreignKey:ToUserID" json:"-"`
	Gift     Gift `gorm:"foreignKey:GiftID" json:"gift,omitempty"`
}
