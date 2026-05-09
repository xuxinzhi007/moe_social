package model

import "time"

// UserGiftStock 用户礼物背包（在「心意」用余额购买后累加，赠送好友时扣减）
type UserGiftStock struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	UserID    uint      `gorm:"not null;uniqueIndex:idx_user_gift" json:"user_id"`
	GiftID    uint      `gorm:"not null;uniqueIndex:idx_user_gift" json:"gift_id"`
	Quantity  int       `gorm:"not null;default:0" json:"quantity"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
