package model

import "time"

// GameSaveSlot 游戏存档槽位
type GameSaveSlot struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID       uint      `gorm:"not null;index:idx_user_slot,unique" json:"user_id"`
	SessionID    uint      `gorm:"not null" json:"session_id"`
	SlotIndex    uint8     `gorm:"not null;index:idx_user_slot,unique" json:"slot_index"`
	Label        string    `gorm:"type:varchar(128);not null;default:''" json:"label"`
	SnapshotJSON string    `gorm:"type:longtext;not null" json:"snapshot_json"`
	TurnCount    int       `gorm:"not null;default:0" json:"turn_count"`
	SceneName    string    `gorm:"type:varchar(128);not null;default:''" json:"scene_name"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (GameSaveSlot) TableName() string { return "game_save_slots" }
