package model

import "time"

// GameNpcTemplate NPC 行为模板表
type GameNpcTemplate struct {
	ID                  uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	NpcKey              string    `gorm:"type:varchar(64);uniqueIndex;not null" json:"npc_key"`
	DisplayName         string    `gorm:"type:varchar(64);not null" json:"display_name"`
	Persona             string    `gorm:"type:text;not null" json:"persona"`
	BaseFavorability    int       `gorm:"not null;default:50" json:"base_favorability"`
	DialogueRulesJSON   string    `gorm:"type:json" json:"dialogue_rules_json"`
	FallbackResponsesJSON string `gorm:"type:json" json:"fallback_responses_json"`
	SceneAffinity       string    `gorm:"type:varchar(128)" json:"scene_affinity"`
	IsActive            bool      `gorm:"not null;default:true" json:"is_active"`
	AgentRuntimeID      *uint     `json:"agent_runtime_id"` // 关联 moe_agent_runtimes.id（可选，NULL=不绑定 Agent）
	CreatedAt           time.Time `json:"created_at"`
	UpdatedAt           time.Time `json:"updated_at"`
}

func (GameNpcTemplate) TableName() string { return "game_npc_templates" }
