package model

import "time"

// CompanionProfile AI 伙伴身份（独立于 LifeEntity，持久化到 DB）。
//
// 一期：UserID 唯一索引 → 每用户一条「当前活跃」profile（产品：单主伙伴）。
// 二期多角色：勿在业务层再加「全局永远一个」死逻辑；演进时应扩展 Companion 域
// （例如多行 + 活跃标记），见 docs/dev/ai-companion-formal-decisions.md。
type CompanionProfile struct {
	ID                   uint      `gorm:"primarykey" json:"id"`
	UserID               uint      `gorm:"uniqueIndex;not null" json:"user_id"`
	Name                  string    `gorm:"size:128;not null" json:"name"`
	Emoji                 string    `gorm:"size:16;not null;default:'🐾'" json:"emoji"`
	AvatarURL             string    `gorm:"size:512" json:"avatar_url"` // 关系层自定义头像；与 Life 居民形象分离
	Persona               string    `gorm:"type:text" json:"persona"`
	PersonalityTraitsJSON string    `gorm:"type:text" json:"personality_traits_json"` // ["温暖","幽默","好奇"]
	GreetingStyle         string    `gorm:"size:32;not null;default:'warm'" json:"greeting_style"` // warm / playful / calm
	RelationshipLevel     int       `gorm:"not null;default:1" json:"relationship_level"`          // 1-10
	IntimacyScore         float64   `gorm:"not null;default:0" json:"intimacy_score"`              // 0-100
	SystemPromptOverride  string    `gorm:"type:text" json:"system_prompt_override"`
	AgentID               string    `gorm:"size:64" json:"agent_id"`
	LifeEntityID          int       `gorm:"default:0" json:"life_entity_id"`
	CreatedAt            time.Time `json:"created_at"`
	UpdatedAt            time.Time `json:"updated_at"`
}

func (CompanionProfile) TableName() string { return "companion_profiles" }
