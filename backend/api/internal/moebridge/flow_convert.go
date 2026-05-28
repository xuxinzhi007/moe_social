package moebridge

import (
	"time"

	moebiz "backend/internal/biz/moe"
	"backend/api/internal/types"
)

// FlowDataFromBiz 将 biz 画布配置转为 API 类型。
func FlowDataFromBiz(cfg moebiz.FlowConfig) types.AdminGetMoeBotFlowData {
	nodes := make([]types.MoeFlowNodeItem, 0, len(cfg.Nodes))
	for _, n := range cfg.Nodes {
		nodes = append(nodes, types.MoeFlowNodeItem{
			Id:        n.ID,
			Type:      n.Type,
			Kind:      n.Kind,
			Label:     n.Label,
			Subtitle:  n.Subtitle,
			StepKey:   n.StepKey,
			ToolName:  n.ToolName,
			PositionX: n.PositionX,
			PositionY: n.PositionY,
			Enabled:   n.Enabled,
			OnFail:    n.OnFail,
			RetryMax:  n.RetryMax,
		})
	}
	edges := make([]types.MoeFlowEdgeItem, 0, len(cfg.Edges))
	for _, e := range cfg.Edges {
		edges = append(edges, types.MoeFlowEdgeItem{
			Id:     e.ID,
			Source: e.Source,
			Target: e.Target,
			Kind:   e.Kind,
			Label:  e.Label,
		})
	}
	out := types.AdminGetMoeBotFlowData{
		AgentKey:     cfg.AgentKey,
		Version:      cfg.Version,
		EntryNodeId:  cfg.EntryNodeID,
		Nodes:        nodes,
		Edges:        edges,
		ViewportZoom: cfg.ViewportZoom,
		ViewportX:    cfg.ViewportX,
		ViewportY:    cfg.ViewportY,
		IsDefault:    cfg.IsDefault,
		Warnings:     cfg.CompileWarnings,
	}
	if !cfg.UpdatedAt.IsZero() {
		out.UpdatedAt = cfg.UpdatedAt.UTC().Format(time.RFC3339)
	}
	return out
}

// FlowConfigFromTypes 将 API 请求体转为 biz 配置。
func FlowConfigFromTypes(req *types.AdminUpsertMoeBotFlowReq) moebiz.FlowConfig {
	if req == nil {
		return moebiz.FlowConfig{}
	}
	nodes := make([]moebiz.FlowNode, 0, len(req.Nodes))
	for _, n := range req.Nodes {
		enabled := n.Enabled
		if n.Type != "tool" && !n.Enabled {
			enabled = true
		}
		nodes = append(nodes, moebiz.FlowNode{
			ID:        n.Id,
			Type:      n.Type,
			Kind:      n.Kind,
			Label:     n.Label,
			Subtitle:  n.Subtitle,
			StepKey:   n.StepKey,
			ToolName:  n.ToolName,
			PositionX: n.PositionX,
			PositionY: n.PositionY,
			Enabled:   enabled,
			OnFail:    n.OnFail,
			RetryMax:  n.RetryMax,
		})
	}
	edges := make([]moebiz.FlowEdge, 0, len(req.Edges))
	for _, e := range req.Edges {
		edges = append(edges, moebiz.FlowEdge{
			ID:     e.Id,
			Source: e.Source,
			Target: e.Target,
			Kind:   e.Kind,
			Label:  e.Label,
		})
	}
	return moebiz.FlowConfig{
		Version:      2,
		EntryNodeID:  "core",
		Nodes:        nodes,
		Edges:        edges,
		ViewportZoom: req.ViewportZoom,
		ViewportX:    req.ViewportX,
		ViewportY:    req.ViewportY,
	}
}
