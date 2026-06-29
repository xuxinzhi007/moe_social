package llmbiz

import (
	"context"
	"fmt"
	"strings"

	"backend/common/errorcode"
	"backend/pkg/llminference"

	"backend/internal/platform/moelog"
)

func platformOutcomeOK(content string, ratio float64, summarized bool) PlatformChatOutcome {
	return PlatformChatOutcome{
		Content:        content,
		RemainingRatio: ratio,
		Summarized:     summarized,
		Code:           errorcode.E_SUCCESS,
		Message:        "操作成功",
		Success:        true,
	}
}

func platformOutcomeErr(err error, summarized bool) PlatformChatOutcome {
	if err == nil {
		err = fmt.Errorf("unknown error")
	}
	return PlatformChatOutcome{
		RemainingRatio: 1,
		Summarized:     summarized,
		Code:           errorcode.E_INTERNAL_ERROR,
		Message:        err.Error(),
		Success:        false,
	}
}

func ExecutePlatformChat(ctx context.Context, deps PlatformChatDeps, in PlatformChatInput) (PlatformChatOutcome, error) {
	if strings.TrimSpace(deps.Inference.BaseURL) == "" {
		return platformOutcomeErr(fmt.Errorf("inference config unavailable"), false), nil
	}

	messages := make([]llminference.Message, 0, len(in.Messages))
	for _, m := range in.Messages {
		messages = append(messages, llminference.Message{Role: m.Role, Content: m.Content})
	}

	chatOpts := llminference.ChatOptions{
		Temperature: in.Temperature,
		TopP:        in.TopP,
		MaxTokens:   in.MaxTokens,
	}

	content, chatErr := chatComplete(ctx, deps, in.Model, messages, chatOpts)
	if chatErr != nil {
		return platformOutcomeErr(fmt.Errorf("调用推理服务失败: %w", chatErr), false), nil
	}

	moelog.WithContext(ctx).Infof("llm chat, model=%s, messages=%d", in.Model, len(in.Messages))

	return platformOutcomeOK(content, 1, false), nil
}

func chatComplete(ctx context.Context, deps PlatformChatDeps, model string, messages []llminference.Message, opts llminference.ChatOptions) (string, error) {
	if deps.ChatComplete != nil {
		return deps.ChatComplete(ctx, model, messages, opts)
	}
	return llminference.Chat(ctx, deps.Inference, model, messages, opts)
}
