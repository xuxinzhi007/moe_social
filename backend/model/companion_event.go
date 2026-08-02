package model

import "time"

// CompanionEvent is the durable, cross-domain timeline for a user's companion.
// It complements relationship events, which remain the legacy milestone view.
type CompanionEvent struct {
	ID                uint      `gorm:"primarykey" json:"id"`
	UserID            uint      `gorm:"not null;index:idx_comp_event_user" json:"user_id"`
	EventType         string    `gorm:"size:48;not null;index:idx_comp_event_type" json:"event_type"`
	SourceDomain      string    `gorm:"size:32;not null;index:idx_comp_event_source" json:"source_domain"`
	SourceID          uint      `gorm:"default:0" json:"source_id"`
	DedupeKey         string    `gorm:"size:160;not null;uniqueIndex:uidx_comp_event_dedupe" json:"dedupe_key"`
	PayloadJSON       string    `gorm:"type:text;not null" json:"payload_json"`
	Visibility        string    `gorm:"size:16;not null;default:'private'" json:"visibility"`
	Sensitivity       string    `gorm:"size:16;not null;default:'normal'" json:"sensitivity"`
	RelationshipDelta float64   `gorm:"not null;default:0" json:"relationship_delta"`
	OccurredAt        time.Time `gorm:"not null;index:idx_comp_event_occurred" json:"occurred_at"`
	CreatedAt         time.Time `json:"created_at"`
}

func (CompanionEvent) TableName() string { return "companion_events" }
