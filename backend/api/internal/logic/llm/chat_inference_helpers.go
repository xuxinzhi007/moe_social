package llm

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	llmbiz "backend/internal/biz/llm"
	"backend/utils"
)

func inferenceConfigFromSvc(svcCtx *svc.ServiceContext) (common.InferenceConfig, error) {
	return common.InferenceFromLLMConf(svcCtx.Config.LLMInference)
}

func toCommonMessages(messages []llmChatMessage) []common.ChatMessage {
	out := make([]common.ChatMessage, len(messages))
	for i, m := range messages {
		out[i] = common.ChatMessage{Role: m.Role, Content: m.Content}
	}
	return out
}

func toBizMessages(messages []llmChatMessage) []llmbiz.ChatMessage {
	out := make([]llmbiz.ChatMessage, len(messages))
	for i, m := range messages {
		out[i] = llmbiz.ChatMessage{Role: m.Role, Content: m.Content}
	}
	return out
}

func toBizChatOptions(opts common.ChatOptions) llmbiz.ChatOptions {
	return llmbiz.ChatOptions{
		Temperature: opts.Temperature,
		TopP:        opts.TopP,
		MaxTokens:   opts.MaxTokens,
	}
}

func (l *ChatLogic) postInferenceChat(
	cfg common.InferenceConfig,
	model string,
	messages []llmChatMessage,
	opts common.ChatOptions,
) (string, error) {
	if l.svcCtx.LLMApp != nil {
		return l.svcCtx.LLMApp.PostChatCompletion(l.ctx, model, toBizMessages(messages), toBizChatOptions(opts))
	}
	client := utils.NewHTTPClient(cfg.TimeoutSeconds)
	return common.PostChatCompletion(
		l.ctx,
		client,
		cfg,
		model,
		toCommonMessages(messages),
		opts,
	)
}
