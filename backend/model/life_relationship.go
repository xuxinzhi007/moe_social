package model

import "time"

// LifeRelationship 实体间社交关系
type LifeRelationship struct {
	ID                uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	WorldID           string    `gorm:"size:64;not null;index" json:"world_id"`
	EntityID          uint      `gorm:"not null;index;uniqueIndex:idx_entity_pair" json:"entity_id"`
	TargetID          uint      `gorm:"not null;index;uniqueIndex:idx_entity_pair" json:"target_id"`
	RelationType      string    `gorm:"size:32;not null;default:'friend'" json:"relation_type"` // friend/rival/mate
	Affinity          float64   `gorm:"default:0" json:"affinity"`                              // 亲密度 0-100
	LastInteractionAt time.Time `json:"last_interaction_at"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

func (LifeRelationship) TableName() string {
	return "life_relationships"
}
