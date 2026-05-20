package user

import (
	"context"
	"strings"

	"backend/api/internal/svc"
	"backend/pkg/memory"
	"backend/pkg/memory/embed"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

// HybridSearchUserFacingMemories Phase 2：关键词 + 向量混合检索（多 embedding 提供方链）。
func HybridSearchUserFacingMemories(
	ctx context.Context,
	svcCtx *svc.ServiceContext,
	userID string,
	memories []*super.UserMemory,
	query string,
	limit int,
) SearchUserMemoriesResult {
	logger := logx.WithContext(ctx)
	records := memory.RecordsFromSuper(memories)
	hcfg := embed.LoadHybridConfig()
	if !hcfg.Enabled {
		return SearchUserFacingMemories(memories, query, limit)
	}

	embMap := map[string][]float32{}
	if embResp, err := svcCtx.SuperRpcClient.ListUserMemoryEmbeddings(ctx, &super.ListUserMemoryEmbeddingsReq{
		UserId: userID,
	}); err == nil {
		for _, it := range embResp.Items {
			if it == nil || it.MemoryKey == "" || len(it.Values) == 0 {
				continue
			}
			vec := make([]float32, len(it.Values))
			for i, v := range it.Values {
				vec[i] = v
			}
			embMap[it.MemoryKey] = vec
		}
	}

	if len(embMap) == 0 && len(records) > 0 {
		if rebuild, err := svcCtx.SuperRpcClient.RebuildUserMemoryEmbeddings(ctx, &super.RebuildUserMemoryEmbeddingsReq{
			UserId: userID,
		}); err == nil && rebuild.Indexed > 0 {
			logger.Infof("memory embeddings rebuilt user_id=%s indexed=%d provider=%s", userID, rebuild.Indexed, rebuild.Provider)
			if embResp, err2 := svcCtx.SuperRpcClient.ListUserMemoryEmbeddings(ctx, &super.ListUserMemoryEmbeddingsReq{UserId: userID}); err2 == nil {
				for _, it := range embResp.Items {
					if it == nil || it.MemoryKey == "" {
						continue
					}
					vec := make([]float32, len(it.Values))
					for i, v := range it.Values {
						vec[i] = v
					}
					embMap[it.MemoryKey] = vec
				}
			}
		}
	}

	var queryVec []float32
	if q := strings.TrimSpace(query); q != "" {
		chain := embed.NewChain(embed.LoadProviders(svcCtx.Config.Ollama.BaseUrl))
		vecs, prov, model, err := chain.Embed(ctx, []string{q})
		if err != nil {
			logger.Errorf("query embed failed user_id=%s: %v", userID, err)
		} else if len(vecs) > 0 {
			queryVec = vecs[0]
			logger.Infof("query embedded user_id=%s provider=%s model=%s", userID, prov, model)
		}
	}

	if len(embMap) == 0 || len(queryVec) == 0 {
		return SearchUserFacingMemories(memories, query, limit)
	}

	res := memory.HybridSearch(
		records,
		query,
		queryVec,
		embMap,
		limit,
		memory.HybridConfig{
			VectorWeight:  hcfg.VectorWeight,
			KeywordWeight: hcfg.KeywordWeight,
		},
	)
	items := make([]UserMemoryDisplayItem, 0, len(res.Items))
	for _, it := range res.Items {
		items = append(items, UserMemoryDisplayItem{
			ID:        it.ID,
			Key:       it.Key,
			Title:     it.Title,
			Content:   it.Content,
			Category:  it.Category,
			UpdatedAt: it.UpdatedAt,
		})
	}
	return SearchUserMemoriesResult{
		Query: res.Query,
		Items: items,
		Total: res.Total,
	}
}
