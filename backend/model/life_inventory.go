package model

import "time"

// LifeInventory 用户背包，记录用户拥有的道具及数量，存储在 life_inventory 表。
type LifeInventory struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    string    `gorm:"size:64;not null;index:idx_life_inv_user;uniqueIndex:idx_life_inv_user_item" json:"user_id"`
	ItemID    uint      `gorm:"not null;index:idx_life_inv_item;uniqueIndex:idx_life_inv_user_item" json:"item_id"`
	Quantity  int       `gorm:"default:0" json:"quantity"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (LifeInventory) TableName() string { return "life_inventory" }
