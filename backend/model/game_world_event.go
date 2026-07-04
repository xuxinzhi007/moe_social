package model

import "time"

// GameWorldEvent 世界自主运转产生的事件（DB = 世界记录）。
type GameWorldEvent struct {
	ID          uint      `gorm:"primarykey" json:"id"`
	SessionID   uint      `gorm:"not null;index:idx_game_world_event_session" json:"session_id"`
	SceneName   string    `gorm:"size:128;not null" json:"scene_name"`
	EventType   string    `gorm:"size:32;not null;default:'ambient'" json:"event_type"`
	Summary     string    `gorm:"type:text;not null" json:"summary"`
	IsDelivered bool      `gorm:"not null;default:false;index:idx_game_world_event_session" json:"is_delivered"`
	CreatedAt   time.Time `json:"created_at"`
}

func (GameWorldEvent) TableName() string { return "game_world_events" }
