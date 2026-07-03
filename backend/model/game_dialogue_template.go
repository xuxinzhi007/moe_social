package model

import "time"

// GameDialogueTemplate 条件对话模板
type GameDialogueTemplate struct {
	ID               uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	NpcKey           string    `gorm:"type:varchar(64);not null;index:idx_npc_priority" json:"npc_key"`
	ConditionJSON    string    `gorm:"type:json;not null" json:"condition_json"`
	ResponseTemplate string    `gorm:"type:text;not null" json:"response_template"`
	FavorDelta       int       `gorm:"not null;default:0" json:"favor_delta"`
	Priority         int       `gorm:"not null;default:0;index:idx_npc_priority" json:"priority"`
	IsEnabled        bool      `gorm:"not null;default:true" json:"is_enabled"`
	IsOneShot        bool      `gorm:"not null;default:false" json:"is_one_shot"`
	CreatedAt        time.Time `json:"created_at"`
}

func (GameDialogueTemplate) TableName() string { return "game_dialogue_templates" }
