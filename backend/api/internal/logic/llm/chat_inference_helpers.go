package llm

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
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

func (l *ChatLogic) postInferenceChat(
	cfg common.InferenceConfig,
	model string,
	messages []llmChatMessage,
	opts common.ChatOptions,
) (string, error) {
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
