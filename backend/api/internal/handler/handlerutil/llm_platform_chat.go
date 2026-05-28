package handlerutil

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	llmbiz "backend/internal/biz/llm"
	"backend/pkg/llminference"
	"backend/utils"
)

func LLMPlatformChatInputFromReq(req *types.LlmChatReq) llmbiz.PlatformChatInput {
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

func LLMPlatformChatDepsFromSvc(svcCtx *svc.ServiceContext) (llmbiz.PlatformChatDeps, error) {
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

func LLMPlatformChatOutcomeToResp(outcome llmbiz.PlatformChatOutcome) *types.LlmChatResp {
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

func LLMPlatformChatCompleter(ctx context.Context, svcCtx *svc.ServiceContext) llmbiz.ChatCompleter {
	return func(callCtx context.Context, model string, messages []llmbiz.ChatMessage, opts llmbiz.ChatOptions) (string, error) {
		if svcCtx.LLMApp != nil {
			return svcCtx.LLMApp.PostChatCompletion(callCtx, model, messages, opts)
		}
		cfg, err := common.InferenceFromLLMConf(svcCtx.Config.LLMInference)
		if err != nil {
			return "", err
		}
		commonMsgs := make([]common.ChatMessage, len(messages))
		for i, m := range messages {
			commonMsgs[i] = common.ChatMessage{Role: m.Role, Content: m.Content}
		}
		client := utils.NewHTTPClient(cfg.TimeoutSeconds)
		return common.PostChatCompletion(ctx, client, cfg, model, commonMsgs, common.ChatOptions{
			Temperature: opts.Temperature,
			TopP:        opts.TopP,
			MaxTokens:   opts.MaxTokens,
		})
	}
}

// LLMChat runs platform chat via biz layer.
func LLMChat(ctx context.Context, svcCtx *svc.ServiceContext, req *types.LlmChatReq) (*types.LlmChatResp, error) {
	deps, buildErr := LLMPlatformChatDepsFromSvc(svcCtx)
	if buildErr != nil {
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(buildErr),
			Content:        "",
			RemainingRatio: 1,
			Summarized:     false,
		}, nil
	}
	deps.ChatComplete = LLMPlatformChatCompleter(ctx, svcCtx)
	outcome, execErr := llmbiz.ExecutePlatformChat(ctx, deps, LLMPlatformChatInputFromReq(req))
	if execErr != nil {
		return nil, execErr
	}
	return LLMPlatformChatOutcomeToResp(outcome), nil
}

// LLMMemoryBudgetMap returns memory budget config as a JSON-friendly map.
func LLMMemoryBudgetMap() map[string]interface{} {
	b := llmbiz.DefaultMemoryBudget()
	return map[string]interface{}{
		"max_injected_memory_items": b.MaxInjectedMemoryItems,
		"max_injected_memory_runes": b.MaxInjectedMemoryRunes,
		"max_history_messages":      b.MaxHistoryMessages,
		"keep_recent_messages":      b.KeepRecentMessages,
		"max_ctx_tokens":            b.MaxCtxTokens,
		"ctx_safe_ratio":            b.CtxSafeRatio,
	}
}
