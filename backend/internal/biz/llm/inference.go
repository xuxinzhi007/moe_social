package llmbiz

import (
	"context"

	"backend/pkg/llminference"
)

// ChatMessage 对话消息（biz 层）。
type ChatMessage struct {
	Role    string
	Content string
}

// ChatOptions 采样参数。
type ChatOptions struct {
	Temperature float64
	TopP        float64
	MaxTokens   int
}

// PostChatCompletion 非流式推理对话补全。
func PostChatCompletion(
	ctx context.Context,
	cfg llminference.Config,
	model string,
	messages []ChatMessage,
	opts ChatOptions,
) (string, error) {
	msgs := make([]llminference.Message, len(messages))
	for i, m := range messages {
		msgs[i] = llminference.Message{Role: m.Role, Content: m.Content}
	}
	return llminference.Chat(ctx, cfg, model, msgs, llminference.ChatOptions{
		Temperature: opts.Temperature,
		TopP:        opts.TopP,
		MaxTokens:   opts.MaxTokens,
	})
}
