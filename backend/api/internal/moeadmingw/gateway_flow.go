package moeadmingw

import (
	"context"

	moebiz "backend/internal/biz/moe"
)

// GetBotFlow 读取 Bot 编排画布（仅 in_process 本地服务）。
func (g *Gateway) GetBotFlow(ctx context.Context, agentKey string) (moebiz.FlowConfig, error) {
	if g == nil {
		return moebiz.FlowConfig{}, errNoBackend
	}
	if g.local != nil {
		return g.local.GetBotFlowConfig(ctx, agentKey)
	}
	return moebiz.DefaultFlowConfig(agentKey), nil
}

// UpsertBotFlow 保存 Bot 编排画布。
func (g *Gateway) UpsertBotFlow(ctx context.Context, agentKey string, in moebiz.FlowConfig) (moebiz.FlowConfig, error) {
	if g == nil {
		return moebiz.FlowConfig{}, errNoBackend
	}
	if g.local != nil {
		return g.local.UpsertBotFlowConfig(ctx, agentKey, in)
	}
	return moebiz.FlowConfig{}, errNoBackend
}

// DeleteBotFlow 删除画布配置并返回默认模板。
func (g *Gateway) DeleteBotFlow(ctx context.Context, agentKey string) (moebiz.FlowConfig, error) {
	if g == nil {
		return moebiz.FlowConfig{}, errNoBackend
	}
	if g.local != nil {
		return g.local.DeleteBotFlowConfig(ctx, agentKey)
	}
	out := moebiz.DefaultFlowConfig(agentKey)
	out.AgentKey = agentKey
	return out, nil
}
