package llm

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	llmbiz "backend/internal/biz/llm"
	"backend/pkg/llminference"
)

func platformChatInputFromReq(req *types.LlmChatReq) llmbiz.PlatformChatInput {
	in := llmbiz.PlatformChatInput{
		Model:               req.Model,
		SessionId:           req.SessionId,
		SourceMsgId:         req.SourceMsgId,
		ClientMemoryApplied: req.ClientMemoryApplied,
		Stream:              req.Stream,
		Temperature:         req.Temperature,
		TopP:                req.TopP,
		MaxTokens:           req.MaxTokens,
		RepeatPenalty:       req.RepeatPenalty,
	}
	if len(req.Messages) > 0 {
		in.Messages = make([]llmbiz.PlatformChatMessage, len(req.Messages))
		for i, m := range req.Messages {
			in.Messages[i] = llmbiz.PlatformChatMessage{Role: m.Role, Content: m.Content}
		}
	}
	return in
}

func platformChatDepsFromSvc(svcCtx *svc.ServiceContext) (llmbiz.PlatformChatDeps, error) {
	cfg, err := common.InferenceFromLLMConf(svcCtx.Config.LLMInference)
	if err != nil {
		return llmbiz.PlatformChatDeps{}, err
	}
	c := svcCtx.Config.LLMInference
	infCfg := llminference.ConfigFrom(cfg.BaseURL, string(cfg.ApiStyle), cfg.TimeoutSeconds, c.MemoryModel)
	deps := llmbiz.PlatformChatDeps{
		Inference:           infCfg,
		MemoryModel:         c.MemoryModel,
		MemorySummaryPrompt: c.MemorySummaryPrompt,
		MemoryExtractPrompt: c.MemoryExtractPrompt,
		MemoryBudget:        llmbiz.DefaultMemoryBudget(),
	}
	if svcCtx.LLMGW != nil {
		deps.Gateway = svcCtx.LLMGW
	}
	return deps, nil
}

func platformChatOutcomeToResp(outcome llmbiz.PlatformChatOutcome) *types.LlmChatResp {
	return &types.LlmChatResp{
		BaseResp: types.BaseResp{
			Code:    outcome.Code,
			Message: outcome.Message,
			Success: outcome.Success,
		},
		Content:        outcome.Content,
		RemainingRatio: outcome.RemainingRatio,
		Summarized:     outcome.Summarized,
	}
}
