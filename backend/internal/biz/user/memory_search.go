package userbiz

import (
	"context"
	"strings"

	"google.golang.org/grpc"

	"backend/pkg/memory"
	"backend/pkg/memory/embed"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

// SearchUserMemoriesResult 记忆库查询结果。
type SearchUserMemoriesResult struct {
	Query string                  `json:"query"`
	Items []UserMemoryDisplayItem `json:"items"`
	Total int                     `json:"total"`
}

// LLMMemoryGateway 混合检索所需的 LLM 记忆 RPC。
type LLMMemoryGateway interface {
	ListUserMemoryEmbeddings(ctx context.Context, in *moe.ListUserMemoryEmbeddingsReq, opts ...grpc.CallOption) (*moe.ListUserMemoryEmbeddingsResp, error)
	RebuildUserMemoryEmbeddings(ctx context.Context, in *moe.RebuildUserMemoryEmbeddingsReq, opts ...grpc.CallOption) (*moe.RebuildUserMemoryEmbeddingsResp, error)
	ListUserMemoryRelations(ctx context.Context, in *moe.ListUserMemoryRelationsReq, opts ...grpc.CallOption) (*moe.ListUserMemoryRelationsResp, error)
}

// MemorySearchParams 混合检索参数。
type MemorySearchParams struct {
	Gateway          LLMMemoryGateway
	InferenceBaseURL string
	UserID           string
	Memories         []*moe.UserMemory
	Query            string
	Limit            int
}

// SearchUserFacingMemories 关键词 + 新近度排序。
func SearchUserFacingMemories(memories []*moe.UserMemory, query string, limit int) SearchUserMemoriesResult {
	res := memory.SearchFacing(memory.RecordsFromSuper(memories), query, limit)
	items := make([]UserMemoryDisplayItem, 0, len(res.Items))
	for _, it := range res.Items {
		items = append(items, UserMemoryDisplayItem{
			ID: it.ID, Key: it.Key, Title: it.Title, Content: it.Content,
			Category: it.Category, UpdatedAt: it.UpdatedAt,
		})
	}
	return SearchUserMemoriesResult{Query: res.Query, Items: items, Total: res.Total}
}

// HybridSearchUserFacingMemories Phase 2+3：混合检索 → 图谱扩展 → rerank。
func HybridSearchUserFacingMemories(ctx context.Context, p MemorySearchParams) SearchUserMemoriesResult {
	logger := logx.WithContext(ctx)
	records := memory.RecordsFromSuper(p.Memories)
	hcfg, _, _ := embed.LoadEnhanceConfig()
	if !hcfg.Enabled {
		return SearchUserFacingMemories(p.Memories, p.Query, p.Limit)
	}

	embMap := map[string][]float32{}
	if p.Gateway != nil {
		if embResp, err := p.Gateway.ListUserMemoryEmbeddings(ctx, &moe.ListUserMemoryEmbeddingsReq{
			UserId: p.UserID,
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
	}

	if len(embMap) == 0 && len(records) > 0 && p.Gateway != nil {
		if rebuild, err := p.Gateway.RebuildUserMemoryEmbeddings(ctx, &moe.RebuildUserMemoryEmbeddingsReq{
			UserId: p.UserID,
		}); err == nil && rebuild.Indexed > 0 {
			logger.Infof("memory embeddings rebuilt user_id=%s indexed=%d provider=%s", p.UserID, rebuild.Indexed, rebuild.Provider)
			if embResp, err2 := p.Gateway.ListUserMemoryEmbeddings(ctx, &moe.ListUserMemoryEmbeddingsReq{UserId: p.UserID}); err2 == nil {
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

	relations := loadMemoryRelations(ctx, p.Gateway, p.UserID)

	var queryVec []float32
	if q := strings.TrimSpace(p.Query); q != "" {
		chain := embed.NewChain(embed.LoadProviders(p.InferenceBaseURL))
		vecs, prov, model, err := chain.Embed(ctx, []string{q})
		if err != nil {
			logger.Errorf("query embed failed user_id=%s: %v", p.UserID, err)
		} else if len(vecs) > 0 {
			queryVec = vecs[0]
			logger.Infof("query embedded user_id=%s provider=%s model=%s", p.UserID, prov, model)
		}
	}

	ec := loadMemoryEnhanceConfig()
	res := memory.HybridSearchEnhanced(records, p.Query, queryVec, embMap, relations, p.Limit, ec)

	items := make([]UserMemoryDisplayItem, 0, len(res.Items))
	for _, it := range res.Items {
		items = append(items, UserMemoryDisplayItem{
			ID: it.ID, Key: it.Key, Title: it.Title, Content: it.Content,
			Category: it.Category, UpdatedAt: it.UpdatedAt,
		})
	}
	return SearchUserMemoriesResult{Query: res.Query, Items: items, Total: res.Total}
}

func loadMemoryRelations(ctx context.Context, gw LLMMemoryGateway, userID string) []memory.Relation {
	if gw == nil {
		return nil
	}
	resp, err := gw.ListUserMemoryRelations(ctx, &moe.ListUserMemoryRelationsReq{UserId: userID})
	if err != nil || resp == nil {
		return nil
	}
	out := make([]memory.Relation, 0, len(resp.Items))
	for _, it := range resp.Items {
		if it == nil || it.FromKey == "" || it.ToKey == "" {
			continue
		}
		out = append(out, memory.Relation{
			FromKey: it.FromKey, ToKey: it.ToKey, Relation: it.Relation, Weight: it.Weight,
		})
	}
	return out
}

func loadMemoryEnhanceConfig() memory.EnhanceConfig {
	hc, rc, gc := embed.LoadEnhanceConfig()
	ec := memory.DefaultEnhanceConfig()
	ec.Hybrid = memory.HybridConfig{
		VectorWeight:  hc.VectorWeight,
		KeywordWeight: hc.KeywordWeight,
	}
	ec.Rerank = memory.RerankConfig{
		Enabled:    rc.Enabled,
		TopK:       rc.TopK,
		MMRLambda:  rc.MMRLambda,
		RecencyMax: 0.15,
		ConfBoost:  0.1,
	}
	ec.Graph = memory.GraphConfig{
		Enabled:   gc.Enabled,
		Hops:      gc.Hops,
		Boost:     gc.Boost,
		MaxExpand: gc.MaxExpand,
	}
	return ec
}
