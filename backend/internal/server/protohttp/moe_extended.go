package protohttp

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	moev1pb "backend/api/moe/v1"
	moebiz "backend/internal/biz/moe"
	apicomm "backend/internal/platform/apicomm"
	"backend/model"
	"backend/pkg/conf"
	"backend/pkg/llminference"
	"backend/pkg/moe/core"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
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
	cfg, err := apicomm.InferenceFromLLMConf(s.inferenceCfg)
	deps := runtime.Deps{Inference: conf.Inference()}
	preferred := runtime.ConfiguredPostModel(deps, model.MoeAgentRuntime{})

	out := &moev1pb.GetInferenceStatusReply{
		BaseUrl:          cfg.BaseURL,
		DefaultPostModel: preferred,
		PreferredModel:   preferred,
	}
	if err != nil || strings.TrimSpace(cfg.BaseURL) == "" {
		out.Message = "llm_inference.base_url is not configured"
		return out, nil
	}

	req, ok := requestFromContext(ctx)
	if !ok {
		return out, nil
	}
	inferCtx, cancel := context.WithTimeout(req.Context(), time.Duration(cfg.TimeoutSeconds)*time.Second)
	defer cancel()

	client := utils.NewHTTPClient(cfg.TimeoutSeconds)
	models, listErr := apicomm.ListModelNames(inferCtx, client, cfg)
	if listErr != nil || len(models) == 0 {
		ollamaModels, ollamaErr := llminference.ListModels(inferCtx, ollamaNativeConfig(s.resolveInferenceConfig()))
		if ollamaErr == nil && len(ollamaModels) > 0 {
			models = ollamaModels
			listErr = nil
		}
	}
	if listErr != nil {
		out.Message = listErr.Error()
		out.Online = apicomm.ProbeInferenceEndpoint(inferCtx, client, cfg)
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

	if len(out.Models) > 0 {
		pick := llminference.PickModel(preferred, out.Models)
		out.EffectiveModel = pick.ModelID
		out.AutoDiscovered = pick.AutoDiscovered
		out.ModelLoaded = out.Online && pick.ModelID != "" && inferenceModelInList(pick.ModelID, out.Models)
		if out.AutoDiscovered && out.ModelLoaded && pick.Preferred != "" && !strings.EqualFold(pick.Preferred, pick.ModelID) {
			out.Message = fmt.Sprintf("auto selected model %s (preferred %s)", pick.ModelID, pick.Preferred)
		}
	} else {
		out.EffectiveModel = strings.TrimSpace(preferred)
		out.ModelLoaded = out.Online && out.EffectiveModel != ""
	}

	if out.Online && len(out.Models) > 0 && !out.ModelLoaded && out.Message == "" {
		out.Message = fmt.Sprintf("inference service is online, but model %s was not found", preferred)
	}

	slot := apicomm.FetchInferenceSlotInfo(inferCtx, client, cfg.BaseURL)
	out.ContextLimit = int32(slot.ContextLimit)
	out.ContextSource = slot.Source
	return out, nil
}

func (s *Server) resolveInferenceConfig() llminference.Config {
	if strings.TrimSpace(s.inferenceCfg.BaseUrl) != "" {
		return llminference.ConfigFrom(
			s.inferenceCfg.BaseUrl,
			s.inferenceCfg.ApiStyle,
			s.inferenceCfg.TimeoutSeconds,
			s.inferenceCfg.MemoryModel,
			s.inferenceCfg.ApiKey,
		)
	}
	return conf.Inference()
}

func ollamaNativeConfig(cfg llminference.Config) llminference.Config {
	out := cfg
	base := strings.TrimRight(strings.TrimSpace(out.BaseURL), "/")
	if strings.HasSuffix(base, "/v1") {
		base = strings.TrimSuffix(base, "/v1")
	}
	out.BaseURL = base
	out.APIStyle = llminference.APIOllama
	return out
}

func (s *Server) ShowInferenceModel(ctx context.Context, in *moev1pb.ShowInferenceModelRequest) (*moev1pb.ShowInferenceModelReply, error) {
	if _, err := s.requireAdmin(); err != nil {
		return nil, err
	}
	modelName := strings.TrimSpace(in.GetModel())
	if modelName == "" {
		return nil, status.Error(codes.InvalidArgument, "model 不能为空")
	}
	cfg := ollamaNativeConfig(s.resolveInferenceConfig())
	if !cfg.Ready() {
		return nil, status.Error(codes.FailedPrecondition, "llm_inference.base_url 未配置")
	}
	info, err := llminference.ShowModel(ctx, cfg, modelName)
	if err != nil {
		return nil, status.Error(codes.Unavailable, fmt.Sprintf("读取模型详情失败: %v", err))
	}
	return &moev1pb.ShowInferenceModelReply{
		Model:          modelName,
		System:         info.SystemPrompt(),
		Modelfile:      info.Modelfile,
		Template:       info.Template,
		ParametersText: info.Parameters,
		Parameters:     llminference.ParseAdminParameters(info.Parameters),
	}, nil
}

func (s *Server) CreateInferenceModel(ctx context.Context, in *moev1pb.CreateInferenceModelRequest) (*moev1pb.CreateInferenceModelReply, error) {
	if _, err := s.requireAdmin(); err != nil {
		return nil, err
	}
	name := strings.TrimSpace(in.GetName())
	if name == "" {
		return nil, status.Error(codes.InvalidArgument, "模型名称不能为空")
	}
	baseModel := strings.TrimSpace(in.GetBaseModel())
	modelfile := strings.TrimSpace(in.GetModelfile())
	if baseModel == "" && modelfile == "" {
		return nil, status.Error(codes.InvalidArgument, "请选择底座模型或填写 Modelfile")
	}
	cfg := ollamaNativeConfig(s.resolveInferenceConfig())
	if !cfg.Ready() {
		return nil, status.Error(codes.FailedPrecondition, "llm_inference.base_url 未配置")
	}
	if in.GetReplaceExisting() {
		_ = llminference.DeleteModel(ctx, cfg, name)
	}
	err := llminference.CreateAdminModel(
		ctx,
		cfg,
		name,
		baseModel,
		strings.TrimSpace(in.GetSystemPrompt()),
		modelfile,
		in.GetParameters(),
	)
	if err != nil {
		return nil, status.Error(codes.Unavailable, fmt.Sprintf("创建模型失败: %v", err))
	}
	return &moev1pb.CreateInferenceModelReply{
		Ok:      true,
		Model:   name,
		Message: "模型创建成功",
	}, nil
}

func (s *Server) DeleteInferenceModel(ctx context.Context, in *moev1pb.DeleteInferenceModelRequest) (*moev1pb.DeleteInferenceModelReply, error) {
	if _, err := s.requireAdmin(); err != nil {
		return nil, err
	}
	modelName := strings.TrimSpace(in.GetModel())
	if modelName == "" {
		return nil, status.Error(codes.InvalidArgument, "model 不能为空")
	}
	cfg := ollamaNativeConfig(s.resolveInferenceConfig())
	if !cfg.Ready() {
		return nil, status.Error(codes.FailedPrecondition, "llm_inference.base_url 未配置")
	}
	if err := llminference.DeleteModel(ctx, cfg, modelName); err != nil {
		return nil, status.Error(codes.Unavailable, fmt.Sprintf("删除模型失败: %v", err))
	}
	return &moev1pb.DeleteInferenceModelReply{
		Ok:      true,
		Model:   modelName,
		Message: "模型已删除",
	}, nil
}

func (s *Server) PullInferenceModel(ctx context.Context, in *moev1pb.PullInferenceModelRequest) (*moev1pb.PullInferenceModelReply, error) {
	if _, err := s.requireAdmin(); err != nil {
		return nil, err
	}
	modelName := strings.TrimSpace(in.GetModel())
	if modelName == "" {
		return nil, status.Error(codes.InvalidArgument, "请输入要拉取的模型名称")
	}
	cfg := ollamaNativeConfig(s.resolveInferenceConfig())
	if !cfg.Ready() {
		return nil, status.Error(codes.FailedPrecondition, "llm_inference.base_url 未配置")
	}
	st, err := llminference.PullModel(ctx, cfg, modelName)
	if err != nil {
		return nil, status.Error(codes.Unavailable, fmt.Sprintf("拉取模型失败: %v", err))
	}
	return &moev1pb.PullInferenceModelReply{
		Ok:      true,
		Model:   modelName,
		Status:  st,
		Message: "模型拉取完成",
	}, nil
}

func (s *Server) ChatInference(ctx context.Context, in *moev1pb.ChatInferenceRequest) (*moev1pb.ChatInferenceReply, error) {
	if _, err := s.requireAdmin(); err != nil {
		return nil, err
	}
	cfg := s.resolveInferenceConfig()
	if !cfg.Ready() {
		return nil, status.Error(codes.FailedPrecondition, "llm_inference.base_url 未配置")
	}
	rawMessages := in.GetMessages()
	if len(rawMessages) == 0 {
		return nil, status.Error(codes.InvalidArgument, "messages 不能为空")
	}
	messages := make([]llminference.Message, 0, len(rawMessages))
	for _, m := range rawMessages {
		role := strings.TrimSpace(m.GetRole())
		content := strings.TrimSpace(m.GetContent())
		if content == "" {
			continue
		}
		if role == "" {
			role = "user"
		}
		messages = append(messages, llminference.Message{Role: role, Content: content})
	}
	if len(messages) == 0 {
		return nil, status.Error(codes.InvalidArgument, "messages 内容不能为空")
	}
	modelName := strings.TrimSpace(in.GetModel())
	if modelName == "" {
		deps := runtime.Deps{Inference: conf.Inference()}
		modelName = runtime.ConfiguredPostModel(deps, model.MoeAgentRuntime{})
	}
	opts := llminference.ChatOptions{
		Temperature:   in.GetTemperature(),
		TopP:          in.GetTopP(),
		RepeatPenalty: in.GetRepeatPenalty(),
		MaxTokens:     int(in.GetMaxTokens()),
	}
	started := time.Now()
	replyText, err := llminference.Chat(ctx, cfg, modelName, messages, opts)
	if err != nil && cfg.APIStyle != llminference.APIOllama {
		if fallbackText, fallbackErr := llminference.Chat(ctx, ollamaNativeConfig(cfg), modelName, messages, opts); fallbackErr == nil {
			replyText = fallbackText
			err = nil
		}
	}
	if err != nil {
		return nil, status.Error(codes.Unavailable, fmt.Sprintf("推理调用失败: %v", err))
	}
	return &moev1pb.ChatInferenceReply{
		Model:      modelName,
		Content:    replyText,
		DurationMs: time.Since(started).Milliseconds(),
	}, nil
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
