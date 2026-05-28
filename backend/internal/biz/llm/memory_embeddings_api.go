package llmbiz

import (
	"context"
	"strings"

	"backend/model"
	"backend/pkg/memory"
	"backend/pkg/memory/embed"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// RebuildUserMemoryEmbeddings 全量重建用户记忆向量。
func RebuildUserMemoryEmbeddings(ctx context.Context, st MemoryStore, in *moe.RebuildUserMemoryEmbeddingsReq, inferenceBaseURL string) (*moe.RebuildUserMemoryEmbeddingsResp, error) {
	db := dbFromStore(ctx, st)
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDUint(in.GetUserId())
	if err != nil {
		return nil, err
	}

	var memories []model.UserMemory
	if err := db.Where("user_id = ?", userID).Order("updated_at desc").Limit(200).Find(&memories).Error; err != nil {
		return nil, err
	}

	texts := make([]string, 0, len(memories))
	keys := make([]string, 0, len(memories))
	for _, m := range memories {
		if memory.IsTechnical(m.Key, m.Source) {
			continue
		}
		v := strings.TrimSpace(m.Value)
		if v == "" {
			continue
		}
		keys = append(keys, m.Key)
		texts = append(texts, m.Key+": "+v)
	}
	if len(texts) == 0 {
		_ = deleteEmbeddingsForUser(db, userID)
		return &moe.RebuildUserMemoryEmbeddingsResp{Indexed: 0}, nil
	}

	chain := embed.NewChain(embed.LoadProviders(inferenceBaseURL))
	vecs, provider, embedModel, err := chain.Embed(ctx, texts)
	if err != nil {
		return nil, err
	}

	_ = deleteEmbeddingsForUser(db, userID)
	for i, key := range keys {
		if i >= len(vecs) {
			break
		}
		_ = upsertMemoryEmbedding(db, userID, key, texts[i], provider, embedModel, vecs[i])
	}

	go syncMemoryRelationsAsync(db, userID)

	return &moe.RebuildUserMemoryEmbeddingsResp{
		Indexed:  int32(len(vecs)),
		Provider: provider,
		Model:    embedModel,
	}, nil
}

// ListUserMemoryEmbeddings 列出用户记忆向量。
func ListUserMemoryEmbeddings(ctx context.Context, st MemoryStore, in *moe.ListUserMemoryEmbeddingsReq) (*moe.ListUserMemoryEmbeddingsResp, error) {
	db := dbFromStore(ctx, st)
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDUint(in.GetUserId())
	if err != nil {
		return nil, err
	}
	m, err := listMemoryEmbeddings(db, userID)
	if err != nil {
		return nil, err
	}
	items := make([]*moe.UserMemoryEmbeddingItem, 0, len(m))
	for key, vec := range m {
		vals := make([]float32, len(vec))
		copy(vals, vec)
		items = append(items, &moe.UserMemoryEmbeddingItem{
			MemoryKey: key,
			Values:    vals,
		})
	}
	return &moe.ListUserMemoryEmbeddingsResp{Items: items}, nil
}

// UpsertUserMemoryEmbedding 直接写入单条记忆向量（供 RPC/调试）。
func UpsertUserMemoryEmbedding(ctx context.Context, st MemoryStore, in *moe.UpsertUserMemoryEmbeddingReq) (*moe.UpsertUserMemoryEmbeddingResp, error) {
	db := dbFromStore(ctx, st)
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDUint(in.GetUserId())
	if err != nil {
		return nil, err
	}
	if in.GetMemoryKey() == "" || len(in.GetValues()) == 0 {
		return nil, ErrMemoryEmptyKey
	}
	vec := make([]float32, len(in.GetValues()))
	for i, v := range in.GetValues() {
		vec[i] = v
	}
	if err := upsertMemoryEmbedding(db, userID, in.GetMemoryKey(), in.GetChunkText(), in.GetProvider(), in.GetModel(), vec); err != nil {
		return nil, err
	}
	return &moe.UpsertUserMemoryEmbeddingResp{}, nil
}

// ListUserMemoryRelations 列出用户记忆关系边。
func ListUserMemoryRelations(ctx context.Context, st MemoryStore, in *moe.ListUserMemoryRelationsReq) (*moe.ListUserMemoryRelationsResp, error) {
	db := dbFromStore(ctx, st)
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDUint(in.GetUserId())
	if err != nil {
		return nil, err
	}
	rels, err := listMemoryRelations(db, userID)
	if err != nil {
		return nil, err
	}
	items := make([]*moe.UserMemoryRelationItem, 0, len(rels))
	for _, r := range rels {
		items = append(items, &moe.UserMemoryRelationItem{
			FromKey:  r.FromKey,
			ToKey:    r.ToKey,
			Relation: r.Relation,
			Weight:   r.Weight,
		})
	}
	return &moe.ListUserMemoryRelationsResp{Items: items}, nil
}
