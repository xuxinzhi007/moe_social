package model

import "time"

// GameStoryArc 故事线配置表
type GameStoryArc struct {
	ID                   uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	ArcKey               string    `gorm:"type:varchar(64);uniqueIndex;not null" json:"arc_key"`
	Title                string    `gorm:"type:varchar(128);not null" json:"title"`
	Description          string    `gorm:"type:text" json:"description"`
	TotalStages          int       `gorm:"not null;default:5" json:"total_stages"`
	StageTriggersJSON    string    `gorm:"type:json;not null" json:"stage_triggers_json"`
	StageNarrativesJSON  string    `gorm:"type:json" json:"stage_narratives_json"`
	ButterflyEffectsJSON string    `gorm:"type:json" json:"butterfly_effects_json"`
	IsActive             bool      `gorm:"not null;default:true" json:"is_active"`
	CreatedAt            time.Time `json:"created_at"`
}

func (GameStoryArc) TableName() string { return "game_story_arcs" }
