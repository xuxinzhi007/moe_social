package platformhttp

import (
	"context"
	"encoding/json"

	platformv1 "backend/api/platform/v1"
	llmbiz "backend/internal/biz/llm"
	"backend/internal/platform/apiconfig"
	"backend/pkg/llminference"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	"google.golang.org/protobuf/types/known/structpb"
)

func (s *Server) GetLlmConfig(ctx context.Context, _ *platformv1.GetLlmConfigReq) (*platformv1.GetLlmConfigResp, error) {
	if !s.hasDeps() {
		return nil, errPlatformUnavailable
	}
	var data map[string]interface{}
	if s.deps.LLMApp != nil {
		data = s.deps.LLMApp.ConfigAPIPayload()
	} else {
		data = llmbiz.ConfigAPIPayload(s.deps.ConfigSnapshot)
	}
	dataStruct, err := structpb.NewStruct(data)
	if err != nil {
		return nil, err
	}
	return &platformv1.GetLlmConfigResp{Code: 200, Message: "获取 LLM 配置成功", Success: true, Data: dataStruct}, nil
}

func (s *Server) LlmCreateAgent(ctx context.Context, in *platformv1.LlmCreateAgentReq) (*platformv1.LlmManagedModelResp, error) {
	if s.deps.LLMApp == nil {
		return nil, kerrors.ServiceUnavailable("LLM_UNAVAILABLE", "模型服务尚未初始化")
	}
	result, err := s.deps.LLMApp.UpsertManagedModel(ctx, llmbiz.CreateAgentInput{
		AgentID: in.GetAgentId(), RequestID: in.GetRequestId(),
		Name: in.GetName(), BaseModel: in.GetBaseModel(), SystemPrompt: in.GetSystemPrompt(),
	})
	if err != nil {
		return nil, err
	}
	return managedModelToProto(result), nil
}

func (s *Server) ListLlmManagedModels(ctx context.Context, _ *platformv1.ListLlmManagedModelsReq) (*platformv1.ListLlmManagedModelsResp, error) {
	if s.deps.LLMApp == nil {
		return nil, kerrors.ServiceUnavailable("LLM_UNAVAILABLE", "模型服务尚未初始化")
	}
	models, err := s.deps.LLMApp.ListManagedModels(ctx)
	if err != nil {
		return nil, err
	}
	resp := &platformv1.ListLlmManagedModelsResp{Code: 200, Success: true, Message: "获取受管模型成功"}
	for _, item := range models {
		resp.Models = append(resp.Models, managedModelToProto(item))
	}
	return resp, nil
}

func (s *Server) GetLlmManagedModel(ctx context.Context, in *platformv1.GetLlmManagedModelReq) (*platformv1.LlmManagedModelResp, error) {
	if s.deps.LLMApp == nil {
		return nil, kerrors.ServiceUnavailable("LLM_UNAVAILABLE", "模型服务尚未初始化")
	}
	result, err := s.deps.LLMApp.GetManagedModel(ctx, in.GetAgentId())
	if err != nil {
		return nil, err
	}
	return managedModelToProto(result), nil
}

func (s *Server) ReconcileLlmManagedModel(ctx context.Context, in *platformv1.GetLlmManagedModelReq) (*platformv1.LlmManagedModelResp, error) {
	if s.deps.LLMApp == nil {
		return nil, kerrors.ServiceUnavailable("LLM_UNAVAILABLE", "模型服务尚未初始化")
	}
	result, err := s.deps.LLMApp.ReconcileManagedModel(ctx, in.GetAgentId())
	if err != nil {
		return nil, err
	}
	return managedModelToProto(result), nil
}

func (s *Server) DeleteLlmManagedModel(ctx context.Context, in *platformv1.DeleteLlmManagedModelReq) (*platformv1.LlmManagedModelResp, error) {
	if s.deps.LLMApp == nil {
		return nil, kerrors.ServiceUnavailable("LLM_UNAVAILABLE", "模型服务尚未初始化")
	}
	result, err := s.deps.LLMApp.DeleteManagedModel(ctx, in.GetAgentId(), in.GetRequestId())
	if err != nil {
		return nil, err
	}
	return managedModelToProto(result), nil
}

func managedModelToProto(result llmbiz.ManagedModelView) *platformv1.LlmManagedModelResp {
	return &platformv1.LlmManagedModelResp{
		Code: 200, Message: result.Message, Success: result.State == "ready" || result.State == "deleted",
		AgentId: result.AgentID, ModelName: result.ModelName, BaseModel: result.BaseModel,
		State: result.State, RequestId: result.RequestID,
		BindingApplied: result.BindingApplied, Retryable: result.Retryable,
	}
}

func (s *Server) LlmChat(ctx context.Context, in *platformv1.LlmChatReq) (*platformv1.LlmChatResp, error) {
	if s.deps.LLMApp == nil {
		return nil, errLLMAppNil
	}
	outcome, err := s.deps.LLMApp.Chat(ctx, platformChatInputFromProto(in))
	if err != nil {
		return nil, err
	}
	return &platformv1.LlmChatResp{Code: int32(outcome.Code), Message: outcome.Message, Success: outcome.Success, Content: outcome.Content, RemainingRatio: outcome.RemainingRatio, Summarized: outcome.Summarized}, nil
}

func platformInferenceCfgFromConfig(c apiconfig.Config) llminference.Config {
	inf := c.LLMInference
	return llminference.ConfigFrom(inf.BaseUrl, inf.ApiStyle, inf.TimeoutSeconds, inf.MemoryModel, inf.ApiKey)
}

func platformConfigSnapshotFromConfig(c apiconfig.Config) llmbiz.ConfigSnapshot {
	inf := c.LLMInference
	return llmbiz.ConfigSnapshot{InferenceBaseURL: inf.BaseUrl, InferenceAPIStyle: inf.ApiStyle, InferenceTimeoutSec: inf.TimeoutSeconds, MemoryModel: inf.MemoryModel, HasSummaryPrompt: inf.MemorySummaryPrompt != "", HasExtractPrompt: inf.MemoryExtractPrompt != "", MemoryBudget: llmbiz.DefaultMemoryBudget()}
}

func platformChatInputFromProto(in *platformv1.LlmChatReq) llmbiz.PlatformChatInput {
	out := llmbiz.PlatformChatInput{Model: in.GetModel(), SessionId: in.GetSessionId(), SourceMsgId: in.GetSourceMsgId(), AgentID: in.GetAgentId(), ClientMemoryApplied: in.GetClientMemoryApplied(), Stream: in.GetStream(), Temperature: in.GetTemperature(), TopP: in.GetTopP(), MaxTokens: int(in.GetMaxTokens()), RepeatPenalty: in.GetRepeatPenalty()}
	if len(in.GetMessages()) > 0 {
		out.Messages = make([]llmbiz.PlatformChatMessage, len(in.GetMessages()))
		for i, m := range in.GetMessages() {
			out.Messages[i] = llmbiz.PlatformChatMessage{Role: m.GetRole(), Content: m.GetContent()}
		}
	}
	return out
}

func moeToolsListValue(tools []interface{}) (*structpb.ListValue, error) {
	raw, err := json.Marshal(tools)
	if err != nil {
		return nil, err
	}
	var items []interface{}
	if err := json.Unmarshal(raw, &items); err != nil {
		return nil, err
	}
	return structpb.NewList(items)
}
