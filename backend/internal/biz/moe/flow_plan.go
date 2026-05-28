package moebiz

import (
	"context"

	"backend/pkg/moe/flowexec"

	"gorm.io/gorm"
)

// FlowConfigToGraph 转为 flowexec 图。
func FlowConfigToGraph(cfg FlowConfig) flowexec.Graph {
	nodes := make([]flowexec.GraphNode, 0, len(cfg.Nodes))
	for _, n := range cfg.Nodes {
		nodes = append(nodes, flowexec.GraphNode{
			ID: n.ID, Type: n.Type, Kind: n.Kind, StepKey: n.StepKey, ToolName: n.ToolName,
			Label: n.Label, Enabled: n.Enabled, OnFail: n.OnFail, RetryMax: n.RetryMax,
		})
	}
	edges := make([]flowexec.GraphEdge, 0, len(cfg.Edges))
	for _, e := range cfg.Edges {
		edges = append(edges, flowexec.GraphEdge{
			ID: e.ID, Source: e.Source, Target: e.Target, Kind: e.Kind,
		})
	}
	entry := cfg.EntryNodeID
	if entry == "" {
		entry = "core"
	}
	return flowexec.Graph{
		Version: cfg.Version, EntryNodeID: entry, Nodes: nodes, Edges: edges,
	}
}

// ResolvePostingPlan 加载并编译 Bot 发帖编排；失败时回退默认计划。
func ResolvePostingPlan(ctx context.Context, db *gorm.DB, agentKey string) (flowexec.Plan, error) {
	cfg, err := GetFlowConfig(ctx, db, agentKey)
	if err != nil {
		return flowexec.DefaultPostingPlan(), err
	}
	plan, err := flowexec.Compile(FlowConfigToGraph(cfg))
	if err != nil {
		p := flowexec.DefaultPostingPlan()
		p.Warnings = append(p.Warnings, err.Error())
		return p, nil
	}
	plan.Warnings = append(plan.Warnings, cfg.CompileWarnings...)
	return plan, nil
}
