package memory

import (
	"strings"
)

// Relation 记忆图谱边（Mem0 graph memory 轻量版）。
type Relation struct {
	FromKey  string
	ToKey    string
	Relation string
	Weight   float64
}

// GraphConfig 图谱扩展检索配置。
type GraphConfig struct {
	Enabled   bool
	Hops      int     // 目前仅 1-hop
	Boost     float64 // 邻居分 = 种子分 * Boost
	MaxExpand int     // 每种子最多扩展邻居数
}

func DefaultGraphConfig() GraphConfig {
	return GraphConfig{
		Enabled:   true,
		Hops:      1,
		Boost:     0.35,
		MaxExpand: 6,
	}
}

// MemoryGraph 邻接表：from -> []Relation。
type MemoryGraph struct {
	adj map[string][]Relation
	byKey map[string]Record
}

// BuildMemoryGraph 合并持久化边 + 规则推断边。
func BuildMemoryGraph(records []Record, persisted []Relation) *MemoryGraph {
	g := &MemoryGraph{
		adj:   make(map[string][]Relation),
		byKey: make(map[string]Record),
	}
	for _, r := range FacingRecords(records) {
		g.byKey[r.Key] = r
	}
	for _, e := range persisted {
		g.addEdge(e)
	}
	inferRelations(g, records)
	return g
}

func (g *MemoryGraph) addEdge(e Relation) {
	if e.FromKey == "" || e.ToKey == "" || e.FromKey == e.ToKey {
		return
	}
	w := e.Weight
	if w <= 0 {
		w = 0.5
	}
	g.adj[e.FromKey] = append(g.adj[e.FromKey], Relation{
		FromKey:  e.FromKey,
		ToKey:    e.ToKey,
		Relation: e.Relation,
		Weight:   w,
	})
}

// inferRelations 同 memory_type、identity 簇、preference 簇弱连接。
func inferRelations(g *MemoryGraph, records []Record) {
	byType := map[string][]string{}
	var identityKeys, prefKeys []string
	for _, r := range FacingRecords(records) {
		mt := strings.TrimSpace(r.MemoryType)
		if mt == "" {
			mt = "fact"
		}
		byType[mt] = append(byType[mt], r.Key)
		kl := strings.ToLower(r.Key)
		switch {
		case strings.Contains(kl, "nickname") || strings.Contains(kl, "identity") || mt == "identity":
			identityKeys = append(identityKeys, r.Key)
		case mt == "preference" || strings.Contains(kl, "preference") || strings.Contains(kl, "hobby"):
			prefKeys = append(prefKeys, r.Key)
		}
	}
	linkCluster(g, identityKeys, "same_cluster", 0.4)
	linkCluster(g, prefKeys, "same_cluster", 0.35)
	for mt, keys := range byType {
		if len(keys) < 2 || len(keys) > 12 {
			continue
		}
		linkCluster(g, keys, "same_type:"+mt, 0.25)
	}
}

func linkCluster(g *MemoryGraph, keys []string, rel string, w float64) {
	if len(keys) < 2 {
		return
	}
	hub := keys[0]
	for i := 1; i < len(keys); i++ {
		g.addEdge(Relation{FromKey: hub, ToKey: keys[i], Relation: rel, Weight: w})
		g.addEdge(Relation{FromKey: keys[i], ToKey: hub, Relation: rel, Weight: w})
	}
}

// ExpandGraph 从种子 key 做 1-hop 扩展，返回额外候选（key -> 衰减分）。
func ExpandGraph(g *MemoryGraph, seeds map[string]float64, cfg GraphConfig) map[string]float64 {
	out := make(map[string]float64)
	if g == nil || !cfg.Enabled || cfg.Hops < 1 {
		return out
	}
	maxN := cfg.MaxExpand
	if maxN <= 0 {
		maxN = 6
	}
	boost := cfg.Boost
	if boost <= 0 {
		boost = 0.35
	}
	expanded := 0
	for from, seedScore := range seeds {
		for _, e := range g.adj[from] {
			if expanded >= maxN*len(seeds) {
				return out
			}
			if _, isSeed := seeds[e.ToKey]; isSeed {
				continue
			}
			add := seedScore * boost * e.Weight
			if add > out[e.ToKey] {
				out[e.ToKey] = add
			}
			expanded++
		}
	}
	return out
}

// RecordByKey 图谱内取记录。
func (g *MemoryGraph) RecordByKey(key string) (Record, bool) {
	r, ok := g.byKey[key]
	return r, ok
}

// Adjacency 导出邻接表（供 RPC 持久化同步）。
func (g *MemoryGraph) Adjacency() map[string][]Relation {
	return g.adj
}
