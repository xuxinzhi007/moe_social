package llmbiz

import (
	"context"

	"backend/pkg/llminference"
)

type PlatformChatMessage struct {
	Role    string
	Content string
}

type PlatformChatInput struct {
	Model               string
	Messages            []PlatformChatMessage
	SessionId           string
	SourceMsgId         string
	ClientMemoryApplied bool
	Stream              bool
	Temperature         float64
	TopP                float64
	MaxTokens           int
	RepeatPenalty       float64
}

type PlatformChatOutcome struct {
	Content        string
	RemainingRatio float64
	Summarized     bool
	Code           int
	Message        string
	Success        bool
}

type ChatCompleter func(ctx context.Context, model string, messages []llminference.Message, opts llminference.ChatOptions) (string, error)

type PlatformChatDeps struct {
	Inference    llminference.Config
	ChatComplete ChatCompleter
}
