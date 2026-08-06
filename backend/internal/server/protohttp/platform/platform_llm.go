package platformhttp

import (
	"context"
	"encoding/json"

	platformv1 "backend/api/platform/v1"
	llmbiz "backend/internal/biz/llm"
	"backend/internal/platform/apiconfig"
	"backend/pkg/llminference"

	"google.golang.org/protobuf/types/known/structpb"
)

func (s *Server) LlmChatRaw(ctx context.Context, _ *platformv1.LlmRawProxyReq) (*platformv1.LlmRawProxyResp, error) {
	if !s.hasDeps() {
		return nil, errPlatformUnavailable
	}
	w, r, ok := httpFromContext(ctx)
	if !ok {
		return nil, errPlatformUnavailable
	}
	if s.deps.LLMApp != nil {
		if err := s.deps.LLMApp.ForwardChatRaw(w, r); err != nil {
			return nil, err
		}
		return nil, nil
	}
	if err := llmbiz.ForwardChatRaw(w, r, s.deps.InferenceConfig); err != nil {
		return nil, err
	}
	return nil, nil
}

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

func (s *Server) LlmModelsRaw(ctx context.Context, _ *platformv1.LlmRawProxyReq) (*platformv1.LlmRawProxyResp, error) {
	if !s.hasDeps() {
		return nil, errPlatformUnavailable
	}
	w, r, ok := httpFromContext(ctx)
	if !ok {
		return nil, errPlatformUnavailable
	}
	if s.deps.LLMApp != nil {
		if err := s.deps.LLMApp.ForwardModelsRaw(w, r); err != nil {
			return nil, err
		}
		return nil, nil
	}
	if err := llmbiz.ForwardModelsRaw(w, r, s.deps.InferenceConfig); err != nil {
		return nil, err
	}
	return nil, nil
}

func (s *Server) LlmShowRaw(ctx context.Context, _ *platformv1.LlmRawProxyReq) (*platformv1.LlmRawProxyResp, error) {
	if !s.hasDeps() {
		return nil, errPlatformUnavailable
	}
	w, r, ok := httpFromContext(ctx)
	if !ok {
		return nil, errPlatformUnavailable
	}
	if s.deps.LLMApp != nil {
		if err := s.deps.LLMApp.ForwardShowRaw(w, r); err != nil {
			return nil, err
		}
		return nil, nil
	}
	if err := llmbiz.ForwardShowRaw(w, r, s.deps.InferenceConfig); err != nil {
		return nil, err
	}
	return nil, nil
}

func (s *Server) LlmCreateAgent(ctx context.Context, in *platformv1.LlmCreateAgentReq) (*platformv1.BaseResp, error) {
	if s.deps.LLMApp == nil {
		return nil, errLLMAppNil
	}
	result := s.deps.LLMApp.CreateAgent(ctx, llmbiz.CreateAgentInput{Name: in.GetName(), BaseModel: in.GetBaseModel(), SystemPrompt: in.GetSystemPrompt()}, s.deps.ModelCache)
	return platformWriteToBaseResp(result), nil
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

func (s *Server) LlmDeleteModel(ctx context.Context, in *platformv1.LlmDeleteModelReq) (*platformv1.BaseResp, error) {
	if s.deps.LLMApp == nil {
		return nil, errLLMAppNil
	}
	result := s.deps.LLMApp.DeleteModel(ctx, in.GetModel(), s.deps.ModelCache)
	return platformWriteToBaseResp(result), nil
}

func (s *Server) LlmDownloadModel(ctx context.Context, in *platformv1.LlmDownloadModelReq) (*platformv1.BaseResp, error) {
	if s.deps.LLMApp == nil {
		return nil, errLLMAppNil
	}
	result := s.deps.LLMApp.DownloadModel(ctx, in.GetModel(), s.deps.ModelCache)
	return platformWriteToBaseResp(result), nil
}

func platformInferenceCfgFromConfig(c apiconfig.Config) llminference.Config {
	inf := c.LLMInference
	return llminference.ConfigFrom(inf.BaseUrl, inf.ApiStyle, inf.TimeoutSeconds, inf.MemoryModel, inf.ApiKey)
}

func platformConfigSnapshotFromConfig(c apiconfig.Config) llmbiz.ConfigSnapshot {
	inf := c.LLMInference
	return llmbiz.ConfigSnapshot{InferenceBaseURL: inf.BaseUrl, InferenceAPIStyle: inf.ApiStyle, InferenceTimeoutSec: inf.TimeoutSeconds, MemoryModel: inf.MemoryModel, HasSummaryPrompt: inf.MemorySummaryPrompt != "", HasExtractPrompt: inf.MemoryExtractPrompt != "", LocalModelsStorageDir: c.LocalModels.StorageDir, LocalModelsCatalogSize: len(c.LocalModels.Catalog), MemoryBudget: llmbiz.DefaultMemoryBudget()}
}

func platformChatInputFromProto(in *platformv1.LlmChatReq) llmbiz.PlatformChatInput {
	out := llmbiz.PlatformChatInput{Model: in.GetModel(), SessionId: in.GetSessionId(), SourceMsgId: in.GetSourceMsgId(), ClientMemoryApplied: in.GetClientMemoryApplied(), Stream: in.GetStream(), Temperature: in.GetTemperature(), TopP: in.GetTopP(), MaxTokens: int(in.GetMaxTokens()), RepeatPenalty: in.GetRepeatPenalty()}
	if len(in.GetMessages()) > 0 {
		out.Messages = make([]llmbiz.PlatformChatMessage, len(in.GetMessages()))
		for i, m := range in.GetMessages() {
			out.Messages[i] = llmbiz.PlatformChatMessage{Role: m.GetRole(), Content: m.GetContent()}
		}
	}
	return out
}

func platformWriteToBaseResp(result llmbiz.PlatformWriteResult) *platformv1.BaseResp {
	return &platformv1.BaseResp{Code: int32(result.Code), Message: result.Message, Success: result.Success}
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
