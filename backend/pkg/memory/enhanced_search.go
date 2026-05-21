package memory

import "strings"

// EnhanceConfig 混合检索后的图谱扩展 + rerank。
type EnhanceConfig struct {
	Hybrid HybridConfig
	Rerank RerankConfig
	Graph  GraphConfig
}

func DefaultEnhanceConfig() EnhanceConfig {
	return EnhanceConfig{
		Hybrid: DefaultHybridConfig(),
		Rerank: DefaultRerankConfig(),
		Graph:  DefaultGraphConfig(),
	}
}

// HybridSearchEnhanced 关键词 + 向量混合 → 图谱扩展 → rerank（Mem0/OpenClaw 风格流水线）。
func HybridSearchEnhanced(
	records []Record,
	query string,
	queryVec []float32,
	embeddings map[string][]float32,
	relations []Relation,
	limit int,
	ec EnhanceConfig,
) SearchResult {
	if limit <= 0 {
		limit = 8
	}
	if limit > 20 {
		limit = 20
	}

	candidates := hybridRankedCandidates(records, query, queryVec, embeddings, ec.Hybrid, limit*4)
	if len(candidates) == 0 {
		return SearchFacing(records, query, limit)
	}

	// 图谱：种子 = 当前 Top 分
	if ec.Graph.Enabled {
		graph := BuildMemoryGraph(records, relations)
		seeds := make(map[string]float64, len(candidates))
		seedN := 8
		if seedN > len(candidates) {
			seedN = len(candidates)
		}
		for i := 0; i < seedN; i++ {
			seeds[candidates[i].rec.Key] = candidates[i].score
		}
		for key, add := range ExpandGraph(graph, seeds, ec.Graph) {
			if rec, ok := graph.RecordByKey(key); ok {
				candidates = append(candidates, rankedCandidate{rec: rec, score: add})
			}
		}
	}

	candidates = RerankCandidates(candidates, query, queryVec, embeddings, limit, ec.Rerank)

	items := make([]DisplayItem, 0, limit)
	for i := 0; i < len(candidates) && len(items) < limit; i++ {
		rec := candidates[i].rec
		if candidates[i].score < 0.12 && strings.TrimSpace(query) != "" {
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

// hybridRankedCandidates 仅产出带分的候选，不截断为 DisplayItem。
func hybridRankedCandidates(
	records []Record,
	query string,
	queryVec []float32,
	embeddings map[string][]float32,
	cfg HybridConfig,
	poolLimit int,
) []rankedCandidate {
	if poolLimit <= 0 {
		poolLimit = 32
	}
	sumW := cfg.VectorWeight + cfg.KeywordWeight
	if sumW <= 0 {
		cfg = DefaultHybridConfig()
		sumW = cfg.VectorWeight + cfg.KeywordWeight
	}
	hasVec := len(queryVec) > 0 && len(embeddings) > 0
	if !hasVec {
		cfg.KeywordWeight = 1
		cfg.VectorWeight = 0
		sumW = 1
	}

	kw := scoreKeywordFacing(records, query)
	vec := scoreVectorFacing(records, queryVec, embeddings)

	byKey := map[string]*rankedCandidate{}
	for key, s := range kw {
		byKey[key] = &rankedCandidate{rec: s.rec, score: s.score * cfg.KeywordWeight / sumW}
	}
	for key, s := range vec {
		if m, ok := byKey[key]; ok {
			m.score += s.score * cfg.VectorWeight / sumW
		} else {
			byKey[key] = &rankedCandidate{rec: s.rec, score: s.score * cfg.VectorWeight / sumW}
		}
	}

	list := make([]rankedCandidate, 0, len(byKey))
	for _, m := range byKey {
		list = append(list, *m)
	}
	sortCandidatesDesc(list)
	if len(list) > poolLimit {
		list = list[:poolLimit]
	}
	return list
}
