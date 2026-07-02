package model

import "time"

// GameWorldItem 会话内动态物品（场景内或玩家背包）。
type GameWorldItem struct {
	ID          uint      `gorm:"primarykey" json:"id"`
	SessionID   uint      `gorm:"not null;index:idx_game_item_session" json:"session_id"`
	SceneID     uint      `gorm:"index" json:"scene_id"`
	Name        string    `gorm:"size:128;not null" json:"name"`
	Description string    `gorm:"type:text" json:"description"`
	IsTakeable  bool      `gorm:"not null;default:true" json:"is_takeable"`
	InInventory bool      `gorm:"not null;default:false;index:idx_game_item_session" json:"in_inventory"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (GameWorldItem) TableName() string { return "game_world_items" }
