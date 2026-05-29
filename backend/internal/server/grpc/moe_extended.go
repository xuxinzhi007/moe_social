package grpcserver

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	moev1pb "backend/api/moe/v1"
	"backend/internal/apilegacy/common"
	moebiz "backend/internal/biz/moe"
	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/core"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func (s *Server) GetBotFlow(ctx context.Context, in *moev1pb.GetBotFlowRequest) (*moev1pb.BotFlowReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	agentKey := strings.TrimSpace(in.GetAgentKey())
	cfg, err := admin.GetBotFlowConfig(ctx, agentKey)
	if err != nil {
		return nil, err
	}
	cfg.AgentKey = agentKey
	return flowToProto(cfg), nil
}

func (s *Server) UpsertBotFlow(ctx context.Context, in *moev1pb.UpsertBotFlowRequest) (*moev1pb.BotFlowReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	agentKey := strings.TrimSpace(in.GetAgentKey())
	inCfg := flowConfigFromProto(in)
	saved, err := admin.UpsertBotFlowConfig(ctx, agentKey, inCfg)
	if err != nil {
		return nil, err
	}
	saved.AgentKey = agentKey
	return flowToProto(saved), nil
}

func (s *Server) DeleteBotFlow(ctx context.Context, in *moev1pb.DeleteBotFlowRequest) (*moev1pb.BotFlowReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	agentKey := strings.TrimSpace(in.GetAgentKey())
	cfg, err := admin.DeleteBotFlowConfig(ctx, agentKey)
	if err != nil {
		return nil, err
	}
	cfg.AgentKey = agentKey
	return flowToProto(cfg), nil
}

func (s *Server) GetInferenceStatus(ctx context.Context, in *moev1pb.GetInferenceStatusRequest) (*moev1pb.GetInferenceStatusReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	cfg, err := common.InferenceFromLLMConf(s.inferenceCfg)
	deps := runtime.Deps{Inference: runtime.LoadInferenceFromViper()}
	preferred := runtime.ConfiguredPostModel(deps, model.MoeAgentRuntime{})

	out := &moev1pb.GetInferenceStatusReply{
		BaseUrl:          cfg.BaseURL,
		DefaultPostModel: preferred,
		PreferredModel:   preferred,
	}
	if err != nil || strings.TrimSpace(cfg.BaseURL) == "" {
		out.Message = "未配置 llm_inference.base_url"
		return out, nil
	}

	req, ok := requestFromContext(ctx)
	if !ok {
		return out, nil
	}
	inferCtx, cancel := context.WithTimeout(req.Context(), time.Duration(cfg.TimeoutSeconds)*time.Second)
	defer cancel()
	client := utils.NewHTTPClient(cfg.TimeoutSeconds)
	models, listErr := common.ListModelNames(inferCtx, client, cfg)
	if listErr != nil {
		out.Message = listErr.Error()
	} else {
		out.Online = true
		out.Models = models
	}

	agentKey := strings.TrimSpace(in.GetAgentKey())
	if agentKey != "" {
		rt, rtErr := admin.FindRuntimeByAgentKey(ctx, agentKey)
		if rtErr != nil {
			return nil, rtErr
		}
		if rt != nil {
			out.RuntimeModel = strings.TrimSpace(rt.ModelName)
			preferred = runtime.ConfiguredPostModel(deps, *rt)
			out.PreferredModel = preferred
			out.DefaultPostModel = preferred
		}
	}

	pick := llminference.PickModel(preferred, out.Models)
	out.EffectiveModel = pick.ModelID
	out.AutoDiscovered = pick.AutoDiscovered
	out.ModelLoaded = out.Online && pick.ModelID != "" && inferenceModelInList(pick.ModelID, out.Models)

	if out.Online && !out.ModelLoaded && out.Message == "" {
		if len(out.Models) == 0 {
			out.Message = "推理服务在线，但未返回可用模型列表"
		} else {
			out.Message = fmt.Sprintf("推理服务在线，但未找到模型「%s」", preferred)
		}
	}
	if out.AutoDiscovered && out.ModelLoaded && pick.Preferred != "" && !strings.EqualFold(pick.Preferred, pick.ModelID) {
		out.Message = fmt.Sprintf("已自动选用「%s」（配置偏好「%s」）", pick.ModelID, pick.Preferred)
	}

	slot := common.FetchInferenceSlotInfo(inferCtx, client, cfg.BaseURL)
	out.ContextLimit = int32(slot.ContextLimit)
	out.ContextSource = slot.Source
	return out, nil
}

func (s *Server) GetToolsSchema(ctx context.Context, _ *moev1pb.GetToolsSchemaRequest) (*moev1pb.GetToolsSchemaReply, error) {
	_ = ctx
	items := toolaudit.BuildSchemaItems()
	out := &moev1pb.GetToolsSchemaReply{DefaultTier: string(core.DefaultTier)}
	for _, it := range items {
		out.Tools = append(out.Tools, &moev1pb.MoeToolSchemaItem{
			Name:         it.Name,
			Description:  it.Description,
			AllowedTiers: it.AllowedTiers,
		})
	}
	openai := tools.OpenAISchemaList()
	if b, err := json.Marshal(openai); err == nil {
		out.OpenaiToolsJson = string(b)
	}
	return out, nil
}

func flowConfigFromProto(in *moev1pb.UpsertBotFlowRequest) moebiz.FlowConfig {
	if in == nil {
		return moebiz.FlowConfig{}
	}
	nodes := make([]moebiz.FlowNode, 0, len(in.GetNodes()))
	for _, n := range in.GetNodes() {
		enabled := n.GetEnabled()
		if n.GetType() != "tool" && !n.GetEnabled() {
			enabled = true
		}
		nodes = append(nodes, moebiz.FlowNode{
			ID:        n.GetId(),
			Type:      n.GetType(),
			Kind:      n.GetKind(),
			Label:     n.GetLabel(),
			Subtitle:  n.GetSubtitle(),
			StepKey:   n.GetStepKey(),
			ToolName:  n.GetToolName(),
			PositionX: n.GetPositionX(),
			PositionY: n.GetPositionY(),
			Enabled:   enabled,
			OnFail:    n.GetOnFail(),
			RetryMax:  int(n.GetRetryMax()),
		})
	}
	edges := make([]moebiz.FlowEdge, 0, len(in.GetEdges()))
	for _, e := range in.GetEdges() {
		edges = append(edges, moebiz.FlowEdge{
			ID:     e.GetId(),
			Source: e.GetSource(),
			Target: e.GetTarget(),
			Kind:   e.GetKind(),
			Label:  e.GetLabel(),
		})
	}
	return moebiz.FlowConfig{
		Version:      2,
		EntryNodeID:  "core",
		Nodes:        nodes,
		Edges:        edges,
		ViewportZoom: in.GetViewportZoom(),
		ViewportX:    in.GetViewportX(),
		ViewportY:    in.GetViewportY(),
	}
}

func flowToProto(cfg moebiz.FlowConfig) *moev1pb.BotFlowReply {
	out := &moev1pb.BotFlowReply{
		AgentKey:     cfg.AgentKey,
		Version:      int32(cfg.Version),
		EntryNodeId:  cfg.EntryNodeID,
		ViewportZoom: cfg.ViewportZoom,
		ViewportX:    cfg.ViewportX,
		ViewportY:    cfg.ViewportY,
		IsDefault:    cfg.IsDefault,
		Warnings:     cfg.CompileWarnings,
	}
	if !cfg.UpdatedAt.IsZero() {
		out.UpdatedAt = cfg.UpdatedAt.Format("2006-01-02 15:04:05")
	}
	for _, n := range cfg.Nodes {
		out.Nodes = append(out.Nodes, &moev1pb.MoeFlowNode{
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
			RetryMax:  int32(n.RetryMax),
		})
	}
	for _, e := range cfg.Edges {
		out.Edges = append(out.Edges, &moev1pb.MoeFlowEdge{
			Id:     e.ID,
			Source: e.Source,
			Target: e.Target,
			Kind:   e.Kind,
			Label:  e.Label,
		})
	}
	return out
}

func inferenceModelInList(id string, models []string) bool {
	for _, m := range models {
		if strings.EqualFold(strings.TrimSpace(m), strings.TrimSpace(id)) {
			return true
		}
	}
	return false
}

func requestFromContext(ctx context.Context) (*http.Request, bool) {
	req, ok := khttp.RequestFromServerContext(ctx)
	return req, ok && req != nil
}
