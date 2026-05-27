package llmbiz

import (
	"context"
	"strings"

	"backend/model"
	"backend/pkg/memory"
	"backend/pkg/memory/embed"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// RebuildUserMemoryEmbeddings 全量重建用户记忆向量。
func RebuildUserMemoryEmbeddings(ctx context.Context, db *gorm.DB, in *super.RebuildUserMemoryEmbeddingsReq, inferenceBaseURL string) (*super.RebuildUserMemoryEmbeddingsResp, error) {
	userID, err := parseUserIDUint(in.GetUserId())
	if err != nil {
		return nil, err
	}

	var memories []model.UserMemory
	if err := db.WithContext(ctx).Where("user_id = ?", userID).Order("updated_at desc").Limit(200).Find(&memories).Error; err != nil {
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
		return &super.RebuildUserMemoryEmbeddingsResp{Indexed: 0}, nil
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

	return &super.RebuildUserMemoryEmbeddingsResp{
		Indexed:  int32(len(vecs)),
		Provider: provider,
		Model:    embedModel,
	}, nil
}

// ListUserMemoryEmbeddings 列出用户记忆向量。
func ListUserMemoryEmbeddings(ctx context.Context, db *gorm.DB, in *super.ListUserMemoryEmbeddingsReq) (*super.ListUserMemoryEmbeddingsResp, error) {
	userID, err := parseUserIDUint(in.GetUserId())
	if err != nil {
		return nil, err
	}
	m, err := listMemoryEmbeddings(db.WithContext(ctx), userID)
	if err != nil {
		return nil, err
	}
	items := make([]*super.UserMemoryEmbeddingItem, 0, len(m))
	for key, vec := range m {
		vals := make([]float32, len(vec))
		copy(vals, vec)
		items = append(items, &super.UserMemoryEmbeddingItem{
			MemoryKey: key,
			Values:    vals,
		})
	}
	return &super.ListUserMemoryEmbeddingsResp{Items: items}, nil
}

// ListUserMemoryRelations 列出用户记忆关系边。
func ListUserMemoryRelations(ctx context.Context, db *gorm.DB, in *super.ListUserMemoryRelationsReq) (*super.ListUserMemoryRelationsResp, error) {
	userID, err := parseUserIDUint(in.GetUserId())
	if err != nil {
		return nil, err
	}
	rels, err := listMemoryRelations(db.WithContext(ctx), userID)
	if err != nil {
		return nil, err
	}
	items := make([]*super.UserMemoryRelationItem, 0, len(rels))
	for _, r := range rels {
		items = append(items, &super.UserMemoryRelationItem{
			FromKey:  r.FromKey,
			ToKey:    r.ToKey,
			Relation: r.Relation,
			Weight:   r.Weight,
		})
	}
	return &super.ListUserMemoryRelationsResp{Items: items}, nil
}
