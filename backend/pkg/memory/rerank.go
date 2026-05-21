package memory

import (
	"math"
	"strings"
	"time"
)

// RerankConfig Phase 3：对混合检索 Top-K 再排序（MMR + 新近度 + 置信度）。
type RerankConfig struct {
	Enabled    bool
	TopK       int     // 从混合分里先取 TopK 再 rerank，默认 24
	MMRLambda  float64 // 1=只看相关，0=只看多样；默认 0.7
	RecencyMax float64 // 新近度加分上限，默认 0.15
	ConfBoost  float64 // 高置信加分，默认 0.1
}

func DefaultRerankConfig() RerankConfig {
	return RerankConfig{
		Enabled:    true,
		TopK:       24,
		MMRLambda:  0.7,
		RecencyMax: 0.15,
		ConfBoost:  0.1,
	}
}

type rankedCandidate struct {
	rec   Record
	score float64
}

// RerankCandidates 在混合分基础上做 MMR（需 queryVec + embMap）及业务加权。
func RerankCandidates(
	candidates []rankedCandidate,
	query string,
	queryVec []float32,
	embMap map[string][]float32,
	limit int,
	cfg RerankConfig,
) []rankedCandidate {
	if !cfg.Enabled || len(candidates) == 0 {
		return trimCandidates(candidates, limit)
	}
	if cfg.TopK <= 0 {
		cfg.TopK = 24
	}
	if cfg.MMRLambda <= 0 {
		cfg.MMRLambda = 0.7
	}
	if limit <= 0 {
		limit = 8
	}

	pool := candidates
	if len(pool) > cfg.TopK {
		pool = append([]rankedCandidate(nil), candidates[:cfg.TopK]...)
	}

	// 业务加权：新近度、置信度、query 与 key 完全匹配
	for i := range pool {
		pool[i].score += recencyBoost(pool[i].rec, cfg.RecencyMax)
		pool[i].score += confidenceBoost(pool[i].rec, cfg.ConfBoost)
		pool[i].score += exactKeyBoost(pool[i].rec.Key, query)
	}

	useMMR := len(queryVec) > 0 && len(embMap) > 0 && cfg.MMRLambda < 1
	if !useMMR {
		sortCandidatesDesc(pool)
		return trimCandidates(pool, limit)
	}

	selected := make([]rankedCandidate, 0, limit)
	remaining := append([]rankedCandidate(nil), pool...)

	for len(selected) < limit && len(remaining) > 0 {
		bestIdx := -1
		bestScore := -math.MaxFloat64
		for i, c := range remaining {
			rel := c.score
			if len(selected) > 0 {
				maxSim := 0.0
				vecC, okC := embMap[c.rec.Key]
				if !okC {
					continue
				}
				for _, s := range selected {
					vecS, okS := embMap[s.rec.Key]
					if !okS {
						continue
					}
					if sim := cosineSimilarity(vecC, vecS); sim > maxSim {
						maxSim = sim
					}
				}
				rel = cfg.MMRLambda*c.score - (1-cfg.MMRLambda)*maxSim
			}
			if rel > bestScore {
				bestScore = rel
				bestIdx = i
			}
		}
		if bestIdx < 0 {
			break
		}
		selected = append(selected, remaining[bestIdx])
		remaining = append(remaining[:bestIdx], remaining[bestIdx+1:]...)
	}
	return selected
}

func recencyBoost(rec Record, maxBoost float64) float64 {
	if maxBoost <= 0 || rec.UpdatedAt.IsZero() {
		return 0
	}
	days := time.Since(rec.UpdatedAt).Hours() / 24
	if days < 0 {
		days = 0
	}
	if days > 30 {
		return 0
	}
	return maxBoost * (1 - days/30)
}

func confidenceBoost(rec Record, maxBoost float64) float64 {
	if maxBoost <= 0 {
		return 0
	}
	c := rec.Confidence
	if c <= 0 {
		return 0
	}
	if c > 1 {
		c = 1
	}
	return maxBoost * c
}

func exactKeyBoost(key, query string) float64 {
	q := strings.TrimSpace(strings.ToLower(query))
	k := strings.TrimSpace(strings.ToLower(key))
	if q == "" || k == "" {
		return 0
	}
	if q == k || strings.Contains(k, q) {
		return 0.25
	}
	return 0
}

func sortCandidatesDesc(list []rankedCandidate) {
	for i := 0; i < len(list); i++ {
		for j := i + 1; j < len(list); j++ {
			if list[j].score > list[i].score {
				list[i], list[j] = list[j], list[i]
			}
		}
	}
}

func trimCandidates(list []rankedCandidate, limit int) []rankedCandidate {
	if limit <= 0 || len(list) <= limit {
		return list
	}
	return list[:limit]
}
