package model

import "time"

// CompanionMemoryConflict stores a candidate that conflicts with a confirmed memory.
type CompanionMemoryConflict struct {
	ID               uint       `gorm:"primarykey" json:"id"`
	UserID           uint       `gorm:"not null;index:idx_comp_mem_conflict_user" json:"user_id"`
	MemoryID         uint       `gorm:"not null;index:idx_comp_mem_conflict_memory" json:"memory_id"`
	MemoryType       string     `gorm:"size:16;not null" json:"memory_type"`
	MemoryKey        string     `gorm:"size:64;not null;index:idx_comp_mem_conflict_key" json:"memory_key"`
	DedupeKey        string     `gorm:"size:160;not null;uniqueIndex:uidx_comp_mem_conflict_dedupe" json:"dedupe_key"`
	CandidateContent string     `gorm:"type:text;not null" json:"candidate_content"`
	Confidence       float64    `gorm:"not null;default:0.5" json:"confidence"`
	Status           string     `gorm:"size:16;not null;default:'pending';index:idx_comp_mem_conflict_status" json:"status"`
	CreatedAt        time.Time  `json:"created_at"`
	ResolvedAt       *time.Time `json:"resolved_at,omitempty"`
}

func (CompanionMemoryConflict) TableName() string { return "companion_memory_conflicts" }
