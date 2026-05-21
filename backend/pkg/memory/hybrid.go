package memory

import (
	"math"
	"strings"
)

// HybridConfig 混合检索配置。
type HybridConfig struct {
	VectorWeight  float64
	KeywordWeight float64
}

// DefaultHybridConfig OpenClaw 风格默认权重。
func DefaultHybridConfig() HybridConfig {
	return HybridConfig{VectorWeight: 0.7, KeywordWeight: 0.3}
}

// HybridSearch 关键词分 + 向量余弦分融合；默认走 HybridSearchEnhanced（含图谱+rerank）。
func HybridSearch(
	records []Record,
	query string,
	queryVec []float32,
	embeddings map[string][]float32,
	limit int,
	cfg HybridConfig,
) SearchResult {
	return HybridSearchEnhanced(records, query, queryVec, embeddings, nil, limit, EnhanceConfig{
		Hybrid: cfg,
		Rerank: DefaultRerankConfig(),
		Graph:  DefaultGraphConfig(),
	})
}

// hybridSearchCore 仅混合分，不图谱/rerank（测试或显式关闭增强时用）。
func hybridSearchCore(
	records []Record,
	query string,
	queryVec []float32,
	embeddings map[string][]float32,
	limit int,
	cfg HybridConfig,
) SearchResult {
	if limit <= 0 {
		limit = 8
	}
	if limit > 20 {
		limit = 20
	}
	if cfg.VectorWeight <= 0 && cfg.KeywordWeight <= 0 {
		cfg = DefaultHybridConfig()
	}
	sumW := cfg.VectorWeight + cfg.KeywordWeight
	if sumW <= 0 {
		sumW = 1
	}

	kw := scoreKeywordFacing(records, query)
	vec := scoreVectorFacing(records, queryVec, embeddings)

	hasVec := len(queryVec) > 0 && len(embeddings) > 0
	if !hasVec {
		cfg.KeywordWeight = 1
		cfg.VectorWeight = 0
		sumW = 1
	}

	type merged struct {
		rec   Record
		score float64
	}
	byKey := map[string]*merged{}
	for key, s := range kw {
		byKey[key] = &merged{rec: s.rec, score: s.score * cfg.KeywordWeight / sumW}
	}
	for key, s := range vec {
		if m, ok := byKey[key]; ok {
			m.score += s.score * cfg.VectorWeight / sumW
		} else {
			byKey[key] = &merged{rec: s.rec, score: s.score * cfg.VectorWeight / sumW}
		}
	}

	list := make([]*merged, 0, len(byKey))
	for _, m := range byKey {
		list = append(list, m)
	}
	for i := 0; i < len(list); i++ {
		for j := i + 1; j < len(list); j++ {
			if list[j].score > list[i].score {
				list[i], list[j] = list[j], list[i]
			}
		}
	}

	if len(list) == 0 {
		return SearchFacing(records, query, limit)
	}

	items := make([]DisplayItem, 0, limit)
	for i := 0; i < len(list) && len(items) < limit; i++ {
		rec := list[i].rec
		if list[i].score < 0.15 && strings.TrimSpace(query) != "" {
			continue
		}
		mType := strings.TrimSpace(rec.MemoryType)
		if mType == "" {
			mType = "fact"
		}
		items = append(items, DisplayItem{
			ID:        rec.ID,
			Key:       rec.Key,
			Title:     TitleFromKey(rec.Key),
			Content:   strings.TrimSpace(rec.Value),
			Category:  CategoryLabel(mType, rec.Key),
			UpdatedAt: formatRecordTime(rec),
		})
	}
	return SearchResult{Query: strings.TrimSpace(query), Items: items, Total: len(items)}
}

type scoreItem struct {
	rec   Record
	score float64
}

func scoreKeywordFacing(records []Record, query string) map[string]scoreItem {
	res := SearchFacing(records, query, 50)
	out := make(map[string]scoreItem, len(res.Items))
	max := float64(len(res.Items))
	for i, it := range res.Items {
		key := it.Key
		if key == "" {
			continue
		}
		for _, r := range records {
			if r.Key == key {
				out[key] = scoreItem{rec: r, score: 1.0 - float64(i)/max}
				break
			}
		}
	}
	return out
}

func scoreVectorFacing(records []Record, queryVec []float32, embeddings map[string][]float32) map[string]scoreItem {
	out := make(map[string]scoreItem)
	if len(queryVec) == 0 {
		return out
	}
	for _, r := range FacingRecords(records) {
		vec, ok := embeddings[r.Key]
		if !ok || len(vec) == 0 {
			continue
		}
		sim := cosineSimilarity(queryVec, vec)
		if sim > 0 {
			out[r.Key] = scoreItem{rec: r, score: sim}
		}
	}
	return out
}

func cosineSimilarity(a, b []float32) float64 {
	n := len(a)
	if len(b) < n {
		n = len(b)
	}
	if n == 0 {
		return 0
	}
	var dot, na, nb float64
	for i := 0; i < n; i++ {
		af := float64(a[i])
		bf := float64(b[i])
		dot += af * bf
		na += af * af
		nb += bf * bf
	}
	if na == 0 || nb == 0 {
		return 0
	}
	return dot / (math.Sqrt(na) * math.Sqrt(nb))
}

func formatRecordTime(r Record) string {
	if r.UpdatedAt.IsZero() {
		return ""
	}
	return r.UpdatedAt.Format("2006-01-02 15:04:05")
}
