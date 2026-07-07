package model

import "time"

// LifeRelationship represents a social relationship between two life entities.
type LifeRelationship struct {
	ID                uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	WorldID           string    `gorm:"size:64;not null;index;uniqueIndex:idx_life_world_entity_pair" json:"world_id"`
	EntityID          uint      `gorm:"not null;index:idx_life_world_entity;uniqueIndex:idx_life_world_entity_pair" json:"entity_id"`
	TargetID          uint      `gorm:"not null;index:idx_life_world_target;uniqueIndex:idx_life_world_entity_pair" json:"target_id"`
	RelationType      string    `gorm:"size:32;not null;default:'friend'" json:"relation_type"`
	Affinity          float64   `gorm:"default:0" json:"affinity"`
	LastInteractionAt time.Time `json:"last_interaction_at"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

func (LifeRelationship) TableName() string {
	return "life_relationships"
}
