package model

import (
	"time"

	"gorm.io/gorm"
)

// UserMemoryEmbedding 记忆条目的向量索引（Phase 2 混合检索；与 user_memories 同行 key 关联）。
type UserMemoryEmbedding struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	UserID      uint           `gorm:"not null;uniqueIndex:idx_user_mem_embed,priority:1" json:"user_id"`
	MemoryKey   string         `gorm:"size:100;not null;uniqueIndex:idx_user_mem_embed,priority:2" json:"memory_key"`
	ChunkText   string         `gorm:"type:text" json:"chunk_text"`
	Embedding   string         `gorm:"type:longtext" json:"embedding"` // JSON 数组 []float64
	Dim         int            `gorm:"not null;default:0" json:"dim"`
	Provider    string         `gorm:"size:32" json:"provider"`
	Model       string         `gorm:"size:64" json:"model"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
