package brain

import (
	"fmt"
	"sort"
	"strings"
)

type Relation struct {
	FromKey  string
	ToKey    string
	Relation string
	Weight   float64
}

// GraphNode 知识图谱节点（管理台可视化）。
type GraphNode struct {
	ID      string `json:"id"`
	Kind    string `json:"kind"`
	Label   string `json:"label"`
	Summary string `json:"summary"`
	Weight  int    `json:"weight"`
	RefID   string `json:"ref_id"`
}

// GraphEdge 知识图谱边。
type GraphEdge struct {
	ID       string  `json:"id"`
	Source   string  `json:"source"`
	Target   string  `json:"target"`
	Relation string  `json:"relation"`
	Weight   float64 `json:"weight"`
}

// GraphView Bot 大脑知识图谱视图。
type GraphView struct {
	AgentKey      string      `json:"agent_key"`
	Nodes         []GraphNode `json:"nodes"`
	Edges         []GraphEdge `json:"edges"`
	EpisodeCount  int         `json:"episode_count"`
	MemoryCount   int         `json:"memory_count"`
	TagCount      int         `json:"tag_count"`
}

func clipSummary(s string, max int) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max]) + "…"
}

// BuildGraphView 将大脑快照与记忆关系合并为可渲染图谱。
func BuildGraphView(snap *Snapshot, relations []Relation, limit int) GraphView {
	if limit <= 0 {
		limit = 80
	}
	out := GraphView{AgentKey: ""}
	if snap == nil {
		return out
	}
	out.AgentKey = snap.AgentKey
	agentID := "agent:" + snap.AgentKey
	out.Nodes = append(out.Nodes, GraphNode{
		ID:      agentID,
		Kind:    "agent",
		Label:   snap.DisplayName,
		Summary: fmt.Sprintf("Bot · %d 条自传", len(snap.Episodes)),
		Weight:  10,
		RefID:   snap.AgentKey,
	})

	tagWeight := map[string]int{}
	for _, st := range snap.TagStats {
		if st.Tag != "" {
			tagWeight[st.Tag] = st.Count
		}
	}

	episodes := snap.Episodes
	if len(episodes) > limit {
		episodes = episodes[:limit]
	}
	out.EpisodeCount = len(snap.Episodes)

	memoryKeys := map[string]bool{}
	for _, m := range snap.Memories {
		if m.Key != "" {
			memoryKeys[m.Key] = true
		}
	}
	out.MemoryCount = len(snap.Memories)

	edgeSeen := map[string]bool{}
	addEdge := func(src, tgt, rel string, w float64) {
		if src == "" || tgt == "" || src == tgt {
			return
		}
		key := src + "|" + tgt + "|" + rel
		if edgeSeen[key] {
			return
		}
		edgeSeen[key] = true
		if w <= 0 {
			w = 0.5
		}
		out.Edges = append(out.Edges, GraphEdge{
			ID:       fmt.Sprintf("e:%s:%s:%s", src, tgt, rel),
			Source:   src,
			Target:   tgt,
			Relation: rel,
			Weight:   w,
		})
	}

	for _, ep := range episodes {
		epID := fmt.Sprintf("episode:%d", ep.ID)
		label := clipSummary(ep.Content, 24)
		if label == "" {
			label = fmt.Sprintf("自传 #%d", ep.ID)
		}
		w := ep.QualityScore
		if w <= 0 {
			w = 50
		}
		out.Nodes = append(out.Nodes, GraphNode{
			ID:      epID,
			Kind:    "episode",
			Label:   label,
			Summary: clipSummary(ep.Content, 120),
			Weight:  w / 10,
			RefID:   fmt.Sprintf("%d", ep.ID),
		})
		addEdge(agentID, epID, "authored", 1)

		if ep.MemoryKey != "" {
			memID := "memory:" + ep.MemoryKey
			addEdge(epID, memID, "stored_as", 0.9)
		}
		for _, tag := range ep.Tags {
			tag = strings.TrimSpace(tag)
			if tag == "" {
				continue
			}
			tagID := "tag:" + tag
			cnt := tagWeight[tag]
			if cnt <= 0 {
				cnt = 1
			}
			addEdge(epID, tagID, "has_tag", 0.7)
			tagWeight[tag] = cnt
		}
		if ep.MoodTag != "" {
			tagID := "tag:" + ep.MoodTag
			addEdge(epID, tagID, "mood", 0.6)
			tagWeight[ep.MoodTag] = max(tagWeight[ep.MoodTag], 1)
		}
	}

	for _, m := range snap.Memories {
		memID := "memory:" + m.Key
		out.Nodes = append(out.Nodes, GraphNode{
			ID:      memID,
			Kind:    "memory",
			Label:   clipSummary(m.Key, 28),
			Summary: clipSummary(m.Value, 120),
			Weight:  4,
			RefID:   m.Key,
		})
		addEdge(agentID, memID, "remembers", 0.8)
	}

	tagIDs := make([]string, 0, len(tagWeight))
	for tag, cnt := range tagWeight {
		tagIDs = append(tagIDs, tag)
		_ = cnt
	}
	sort.Slice(tagIDs, func(i, j int) bool {
		return tagWeight[tagIDs[i]] > tagWeight[tagIDs[j]]
	})
	if len(tagIDs) > 40 {
		tagIDs = tagIDs[:40]
	}
	out.TagCount = len(tagIDs)
	for _, tag := range tagIDs {
		tagID := "tag:" + tag
		cnt := tagWeight[tag]
		kind := "tag"
		if strings.Contains(tag, ":") {
			kind = "topic"
		}
		out.Nodes = append(out.Nodes, GraphNode{
			ID:      tagID,
			Kind:    kind,
			Label:   tag,
			Summary: fmt.Sprintf("出现 %d 次", cnt),
			Weight:  min(cnt, 12),
			RefID:   tag,
		})
	}

	for _, rel := range relations {
		src := graphNodeIDForMemoryKey(rel.FromKey)
		tgt := graphNodeIDForMemoryKey(rel.ToKey)
		if src == "" || tgt == "" {
			continue
		}
		addEdge(src, tgt, rel.Relation, rel.Weight)
	}

	return out
}

func graphNodeIDForMemoryKey(key string) string {
	key = strings.TrimSpace(key)
	if key == "" {
		return ""
	}
	return "memory:" + key
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
