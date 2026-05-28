package flowexec

import (
	"fmt"
	"strings"
)

// Compile 将画布编译为 E1 线性执行计划（仅沿 default 边，单后继）。
func Compile(g Graph) (Plan, error) {
	normalizeGraph(&g)
	if len(g.Nodes) == 0 {
		return Plan{}, fmt.Errorf("flow: 无节点")
	}
	entry := strings.TrimSpace(g.EntryNodeID)
	if entry == "" {
		entry = "core"
	}
	byID := make(map[string]GraphNode, len(g.Nodes))
	for _, n := range g.Nodes {
		byID[n.ID] = n
	}
	defaultNext := map[string]string{}
	for _, e := range g.Edges {
		k := strings.TrimSpace(e.Kind)
		if k != "" && k != "default" {
			continue
		}
		src := strings.TrimSpace(e.Source)
		tgt := strings.TrimSpace(e.Target)
		if src == "" || tgt == "" {
			continue
		}
		if _, exists := defaultNext[src]; exists {
			return Plan{}, fmt.Errorf("flow: 节点 %s 有多条 default 出边（E1 仅支持线性链）", src)
		}
		defaultNext[src] = tgt
	}
	var warnings []string
	order := make([]GraphNode, 0, len(g.Nodes))
	visited := make(map[string]bool)
	cur := entry
	for cur != "" {
		if visited[cur] {
			return Plan{}, fmt.Errorf("flow: 检测到环（%s）", cur)
		}
		visited[cur] = true
		n, ok := byID[cur]
		if !ok {
			break
		}
		if n.Enabled && n.Type != "core" {
			if n.Type == "step" || (n.Type == "tool" && n.ToolName != "") {
				order = append(order, n)
			}
		} else if n.Type == "core" {
			// skip
		} else if !n.Enabled {
			warnings = append(warnings, fmt.Sprintf("节点 %s 已禁用，跳过执行", cur))
		}
		next, ok := defaultNext[cur]
		if !ok {
			break
		}
		cur = next
	}
	if len(order) == 0 {
		return Plan{}, fmt.Errorf("flow: 无可执行节点")
	}
	if err := validatePostingPath(order); err != nil {
		return Plan{}, err
	}
	return Plan{Nodes: order, Warnings: warnings}, nil
}

func validatePostingPath(order []GraphNode) error {
	hasLLM := false
	hasPost := false
	for _, n := range order {
		k := execKind(n)
		if k == "llm_generate" {
			hasLLM = true
		}
		if k == "post_create" {
			hasPost = true
		}
	}
	if !hasLLM || !hasPost {
		return fmt.Errorf("flow: 发帖主路径须包含 llm_generate 与 post_create")
	}
	return nil
}

// NodeExecKind 返回节点执行器类型。
func NodeExecKind(n GraphNode) string {
	return execKind(n)
}

// NodeLabel 返回展示标签。
func NodeLabel(n GraphNode, fallback string) string {
	if strings.TrimSpace(n.Label) != "" {
		return n.Label
	}
	return fallback
}

func execKind(n GraphNode) string {
	k := strings.TrimSpace(n.Kind)
	if k != "" {
		return k
	}
	if n.Type == "tool" {
		return "tool"
	}
	switch strings.TrimSpace(n.StepKey) {
	case "load_runtime":
		return "load_runtime"
	case "gather_memory":
		return "gather_memory"
	case "topic_profile", "resolve_model", "assemble_prompt":
		return "prep"
	case "gen_attempt":
		return "llm_generate"
	case "generate_finalize":
		return "qc"
	case "post_create":
		return "post_create"
	case "record_episode":
		return "record_episode"
	}
	switch n.ID {
	case "load":
		return "load_runtime"
	case "gather":
		return "gather_memory"
	case "prep":
		return "prep"
	case "llm":
		return "llm_generate"
	case "qc":
		return "qc"
	case "post":
		return "post_create"
	case "episode":
		return "record_episode"
	}
	return ""
}

func normalizeGraph(g *Graph) {
	for i := range g.Nodes {
		n := &g.Nodes[i]
		if n.Type != "core" && n.Type != "tool" && n.Type != "step" {
			n.Type = "step"
		}
		if n.Kind == "" {
			n.Kind = execKind(*n)
		}
		if n.Type == "tool" && n.ToolName != "" && n.Kind == "" {
			n.Kind = "tool"
		}
	}
	for i := range g.Edges {
		if strings.TrimSpace(g.Edges[i].Kind) == "" {
			g.Edges[i].Kind = "default"
		}
	}
}

// DefaultPostingPlan 与历史 RunOnce 等价的默认线性计划。
func DefaultPostingPlan() Plan {
	g := Graph{
		Version:     2,
		EntryNodeID: "core",
		Nodes: []GraphNode{
			{ID: "load", Type: "step", Kind: "load_runtime", StepKey: "load_runtime", Enabled: true},
			{ID: "gather", Type: "step", Kind: "gather_memory", StepKey: "gather_memory", Enabled: true},
			{ID: "prep", Type: "step", Kind: "prep", StepKey: "topic_profile", Enabled: true},
			{ID: "llm", Type: "step", Kind: "llm_generate", StepKey: "gen_attempt", Enabled: true},
			{ID: "qc", Type: "step", Kind: "qc", StepKey: "generate_finalize", Enabled: true},
			{ID: "post", Type: "step", Kind: "post_create", StepKey: "post_create", Enabled: true},
			{ID: "episode", Type: "step", Kind: "record_episode", StepKey: "record_episode", Enabled: true},
		},
		Edges: []GraphEdge{
			{Source: "core", Target: "load", Kind: "default"},
			{Source: "load", Target: "gather", Kind: "default"},
			{Source: "gather", Target: "prep", Kind: "default"},
			{Source: "prep", Target: "llm", Kind: "default"},
			{Source: "llm", Target: "qc", Kind: "default"},
			{Source: "qc", Target: "post", Kind: "default"},
			{Source: "post", Target: "episode", Kind: "default"},
		},
	}
	p, err := Compile(g)
	if err != nil {
		return Plan{Nodes: g.Nodes[0:7]}
	}
	return p
}
