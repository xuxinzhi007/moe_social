package llmdata

import (
	"context"

	llmbiz "backend/internal/biz/llm"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.MemoryStore（P4-D）。
func NewStore(db *gorm.DB) llmbiz.MemoryStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) llmbiz.MemoryStore {
	if s.db == nil {
		return s
	}
	return &store{db: s.db.WithContext(ctx)}
}
