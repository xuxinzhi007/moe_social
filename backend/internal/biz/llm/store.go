package llmbiz

import (
	"context"

	"gorm.io/gorm"
)

// MemoryStore 用户记忆持久化（P4-D；默认由 internal/data/llm 实现）。
type MemoryStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) MemoryStore
}

func dbFromStore(ctx context.Context, st MemoryStore) *gorm.DB {
	if st == nil {
		return nil
	}
	if ctx != nil {
		return st.WithContext(ctx).Raw()
	}
	return st.Raw()
}
