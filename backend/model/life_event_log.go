package model

import "time"

// LifeEventLog 数字生命行为事件日志，存储在 life_event_logs 表。
type LifeEventLog struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	WorldID     string    `json:"world_id" gorm:"size:64;not null;index:idx_life_event_world;index:idx_life_event_world_created,priority:1"`
	EntityID    uint      `json:"entity_id" gorm:"not null;index:idx_life_event_entity"`
	EntityType  string    `json:"entity_type" gorm:"size:64"`                    // 实体名称，冗余存储便于查询
	EventType   string    `json:"event_type" gorm:"size:32;not null"`            // eat/sleep/walk/idle/mood_change/interaction
	Description string    `json:"description" gorm:"size:512"`                   // 事件描述文本
	PositionX   float64   `json:"position_x"`
	PositionY   float64   `json:"position_y"`
	Importance  int8      `gorm:"default:0;index:idx_life_event_importance_created,priority:1" json:"importance"`
	CreatedAt   time.Time `json:"created_at" gorm:"index:idx_life_event_created;index:idx_life_event_world_created,priority:2;index:idx_life_event_importance_created,priority:2"`
}

func (LifeEventLog) TableName() string { return "life_event_logs" }
