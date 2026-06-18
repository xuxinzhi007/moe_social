package platformhttp

import (
	"context"
	"encoding/json"

	platformv1 "backend/api/platform/v1"
	llmbiz "backend/internal/biz/llm"
	"backend/internal/platform/svc"
	"backend/pkg/llminference"

	"google.golang.org/protobuf/types/known/structpb"
)

func (s *Server) LlmChatRaw(ctx context.Context, _ *platformv1.LlmRawProxyReq) (*platformv1.LlmRawProxyResp, error) {
	svcCtx, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	w, r, ok := httpFromContext(ctx)
	if !ok {
		return nil, errSvcCtxNil
	}
	if svcCtx.LLMApp != nil {
		if err := svcCtx.LLMApp.ForwardChatRaw(w, r); err != nil {
			return nil, err
		}
		return nil, nil
	}
	cfg := platformInferenceCfgFromSvc(svcCtx)
	if err := llmbiz.ForwardChatRaw(w, r, cfg); err != nil {
		return nil, err
	}
	return nil, nil
}

func (s *Server) GetLlmConfig(ctx context.Context, _ *platformv1.GetLlmConfigReq) (*platformv1.GetLlmConfigResp, error) {
	svcCtx, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	var data map[string]interface{}
	if svcCtx.LLMApp != nil {
		data = svcCtx.LLMApp.ConfigAPIPayload()
	} else {
		data = llmbiz.ConfigAPIPayload(platformConfigSnapshotFromSvc(svcCtx))
	}
	dataStruct, err := structpb.NewStruct(data)
	if err != nil {
		return nil, err
	}
	return &platformv1.GetLlmConfigResp{
		Code: 200, Message: "获取 LLM 配置成功", Success: true, Data: dataStruct,
	}, nil
}

func (s *Server) LlmModelsRaw(ctx context.Context, _ *platformv1.LlmRawProxyReq) (*platformv1.LlmRawProxyResp, error) {
	svcCtx, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	w, r, ok := httpFromContext(ctx)
	if !ok {
		return nil, errSvcCtxNil
	}
	if svcCtx.LLMApp != nil {
		if err := svcCtx.LLMApp.ForwardModelsRaw(w, r); err != nil {
			return nil, err
		}
		return nil, nil
	}
	cfg := platformInferenceCfgFromSvc(svcCtx)
	if err := llmbiz.ForwardModelsRaw(w, r, cfg); err != nil {
		return nil, err
	}
	return nil, nil
}

func (s *Server) LlmShowRaw(ctx context.Context, _ *platformv1.LlmRawProxyReq) (*platformv1.LlmRawProxyResp, error) {
	svcCtx, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	w, r, ok := httpFromContext(ctx)
	if !ok {
		return nil, errSvcCtxNil
	}
	if svcCtx.LLMApp != nil {
		if err := svcCtx.LLMApp.ForwardShowRaw(w, r); err != nil {
			return nil, err
		}
		return nil, nil
	}
	cfg := platformInferenceCfgFromSvc(svcCtx)
	if err := llmbiz.ForwardShowRaw(w, r, cfg); err != nil {
		return nil, err
	}
	return nil, nil
}

func (s *Server) LlmCreateAgent(ctx context.Context, in *platformv1.LlmCreateAgentReq) (*platformv1.BaseResp, error) {
	svcCtx, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	if svcCtx.LLMApp == nil {
		return nil, errLLMAppNil
	}
	result := svcCtx.LLMApp.CreateAgent(ctx, llmbiz.CreateAgentInput{
		Name: in.GetName(), BaseModel: in.GetBaseModel(), SystemPrompt: in.GetSystemPrompt(),
	}, svcCtx.ModelCache)
	return platformWriteToBaseResp(result), nil
}

func (s *Server) LlmChat(ctx context.Context, in *platformv1.LlmChatReq) (*platformv1.LlmChatResp, error) {
	svcCtx, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	if svcCtx.LLMApp == nil {
		return nil, errLLMAppNil
	}
	outcome, err := svcCtx.LLMApp.Chat(ctx, platformChatInputFromProto(in))
	if err != nil {
		return nil, err
	}
	return &platformv1.LlmChatResp{
		Code: int32(outcome.Code), Message: outcome.Message, Success: outcome.Success,
		Content: outcome.Content, RemainingRatio: outcome.RemainingRatio, Summarized: outcome.Summarized,
	}, nil
}

func (s *Server) LlmDeleteModel(ctx context.Context, in *platformv1.LlmDeleteModelReq) (*platformv1.BaseResp, error) {
	svcCtx, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	if svcCtx.LLMApp == nil {
		return nil, errLLMAppNil
	}
	result := svcCtx.LLMApp.DeleteModel(ctx, in.GetModel(), svcCtx.ModelCache)
	return platformWriteToBaseResp(result), nil
}

func (s *Server) LlmDownloadModel(ctx context.Context, in *platformv1.LlmDownloadModelReq) (*platformv1.BaseResp, error) {
	svcCtx, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	if svcCtx.LLMApp == nil {
		return nil, errLLMAppNil
	}
	result := svcCtx.LLMApp.DownloadModel(ctx, in.GetModel(), svcCtx.ModelCache)
	return platformWriteToBaseResp(result), nil
}

func platformInferenceCfgFromSvc(svcCtx *svc.ServiceContext) llminference.Config {
	if svcCtx == nil {
		return llminference.Config{}
	}
	c := svcCtx.Config.LLMInference
	return llminference.ConfigFrom(c.BaseUrl, c.ApiStyle, c.TimeoutSeconds, c.MemoryModel)
}

func platformConfigSnapshotFromSvc(svcCtx *svc.ServiceContext) llmbiz.ConfigSnapshot {
	if svcCtx == nil {
		return llmbiz.ConfigSnapshot{MemoryBudget: llmbiz.DefaultMemoryBudget()}
	}
	c := svcCtx.Config
	inf := c.LLMInference
	return llmbiz.ConfigSnapshot{
		InferenceBaseURL:       inf.BaseUrl,
		InferenceAPIStyle:      inf.ApiStyle,
		InferenceTimeoutSec:    inf.TimeoutSeconds,
		MemoryModel:            inf.MemoryModel,
		HasSummaryPrompt:       inf.MemorySummaryPrompt != "",
		HasExtractPrompt:       inf.MemoryExtractPrompt != "",
		LocalModelsStorageDir:  c.LocalModels.StorageDir,
		LocalModelsCatalogSize: len(c.LocalModels.Catalog),
		MemoryBudget:           llmbiz.DefaultMemoryBudget(),
	}
}

func platformChatInputFromProto(in *platformv1.LlmChatReq) llmbiz.PlatformChatInput {
	out := llmbiz.PlatformChatInput{
		Model: in.GetModel(), SessionId: in.GetSessionId(), SourceMsgId: in.GetSourceMsgId(),
		ClientMemoryApplied: in.GetClientMemoryApplied(), Stream: in.GetStream(),
		Temperature: in.GetTemperature(), TopP: in.GetTopP(), MaxTokens: int(in.GetMaxTokens()),
		RepeatPenalty: in.GetRepeatPenalty(),
	}
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
