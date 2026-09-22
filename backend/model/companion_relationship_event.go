package model

import "time"

// CompanionRelationshipEvent records a meaningful change in a user's bond.
type CompanionRelationshipEvent struct {
	ID                uint      `gorm:"primarykey" json:"id"`
	UserID            uint      `gorm:"not null;index:idx_comp_rel_event_user;index:idx_comp_rel_event_user_created,priority:1" json:"user_id"`
	EventType         string    `gorm:"size:32;not null;index:idx_comp_rel_event_type" json:"event_type"`
	Title             string    `gorm:"size:128;not null" json:"title"`
	Content           string    `gorm:"type:text;not null" json:"content"`
	RelationshipLevel int       `gorm:"not null;default:1" json:"relationship_level"`
	IntimacyScore     float64   `gorm:"not null;default:0" json:"intimacy_score"`
	CreatedAt         time.Time `gorm:"index:idx_comp_rel_event_user_created,priority:2,sort:desc" json:"created_at"`
}

func (CompanionRelationshipEvent) TableName() string { return "companion_relationship_events" }
