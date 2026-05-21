package model

import (
	"time"

	"gorm.io/gorm"
)

// UserMemoryRelation 记忆图谱边（Phase 3：Mem0 graph memory 轻量版）。
type UserMemoryRelation struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	UserID    uint           `gorm:"not null;index:idx_umrel_user" json:"user_id"`
	FromKey   string         `gorm:"size:100;not null;uniqueIndex:idx_umrel_edge,priority:1" json:"from_key"`
	ToKey     string         `gorm:"size:100;not null;uniqueIndex:idx_umrel_edge,priority:2" json:"to_key"`
	Relation  string         `gorm:"size:32;not null;uniqueIndex:idx_umrel_edge,priority:3" json:"relation"`
	Weight    float64        `gorm:"not null;default:0.5" json:"weight"`
	Source    string         `gorm:"size:32" json:"source"` // inferred | manual | upsert
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}
