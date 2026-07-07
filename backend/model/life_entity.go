package model

import "time"

// LifeEntity 数字生命实体（NPC/宠物等），存储在 life_entities 表。
type LifeEntity struct {
	ID             uint      `json:"id" gorm:"primaryKey"`
	WorldID        string    `json:"world_id" gorm:"size:64;not null;index:idx_life_entity_world"`
	Name           string    `json:"name" gorm:"size:128;not null"`
	Emoji          string    `json:"emoji" gorm:"size:16"`
	Hunger         float64   `json:"hunger" gorm:"default:80"`        // 0-100, 越高越饱
	Energy         float64   `json:"energy" gorm:"default:80"`        // 0-100, 越高越有精力
	Mood           float64   `json:"mood" gorm:"default:70"`          // 0-100, 越高越开心
	CurrentAction  string    `json:"current_action" gorm:"size:32;default:idle"` // idle/walking/eating/sleeping/seeking_food/seeking_rest/wandering/talking
	PositionX      float64   `json:"position_x" gorm:"default:640"`   // 0-1280
	PositionY      float64   `json:"position_y" gorm:"default:360"`   // 0-720
	TargetEntityID *uint     `json:"target_entity_id,omitempty"`      // 交互目标
	IsAlive        bool      `json:"is_alive" gorm:"default:true;index:idx_life_entity_alive"` // 是否存活，死亡后标记为 false
	LastActionAt   time.Time `json:"last_action_at"`
	UpdatedAt      time.Time `json:"updated_at"`
	CreatedAt      time.Time `json:"created_at"`
}

func (LifeEntity) TableName() string { return "life_entities" }
