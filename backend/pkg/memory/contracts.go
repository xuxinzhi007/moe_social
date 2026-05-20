package memory

import "context"

// Store L1 记忆文本库的持久化抽象；RPC/API/其他服务各自实现。
type Store interface {
	ListByUser(ctx context.Context, userID string, limit, offset int) ([]Record, int64, error)
	Upsert(ctx context.Context, rec Record) (Record, error)
	DeleteByKey(ctx context.Context, userID, key string) error
}

// Searcher 可选：由 Store 全量拉取后走包内 Search；大库可换向量/全文实现。
type Searcher interface {
	Search(ctx context.Context, userID, query string, limit int) (SearchResult, error)
}

// ProfileCache 画像摘要缓存（按 user + memory_type）。
type ProfileCache interface {
	List(ctx context.Context, userID string, limit int) ([]ProfileSummary, error)
	Rebuild(ctx context.Context, userID string) error
}
