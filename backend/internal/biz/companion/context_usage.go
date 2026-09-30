package companionbiz

import (
	"context"
	"fmt"
	"strings"

	"backend/pkg/conf"
	"backend/pkg/llminference"
)

// chatMaxOutputTokens 是单轮回复预留，和发给模型的 MaxTokens 同一口径。
const chatMaxOutputTokens = 480

// messageOverheadTokens 粗算一条消息的角色包装开销。
const messageOverheadTokens = 4

// ContextUsage 是下一轮请求的上下文占用估算。
type ContextUsage struct {
	PromptTokens    int  `json:"prompt_tokens"`
	PersonaTokens   int  `json:"persona_tokens"`
	HistoryTokens   int  `json:"history_tokens"`
	HistoryMessages int  `json:"history_messages"`
	HistoryLimit    int  `json:"history_limit"`
	ContextLimit    int  `json:"context_limit"`
	OutputReserve   int  `json:"output_reserve"`
	Overflow        bool `json:"overflow"`
}

// ChatContextUsage 按和正式聊天相同的拼装方式估算占用，不附加一条空的用户消息。
func (e *Engine) ChatContextUsage(ctx context.Context, userID uint) (ContextUsage, error) {
	snapshot, err := e.BuildContext(ctx, userID, "")
	if err != nil {
		return ContextUsage{}, fmt.Errorf("measure companion context: %w", err)
	}
	profile := snapshot.Profile
	if profile == nil {
		profile = defaultProfile(userID)
	}
	messages := buildMessagesWithContext(
		profile,
		snapshot.State,
		snapshot.Memories,
		snapshot.History,
		snapshot.RelationshipEvents,
		snapshot.UnfinishedTopics,
		"",
		snapshot.Scene,
	)
	messages = dropEmptyTrailingUser(messages)
	limit := e.MaxHistoryTurns
	if limit <= 0 {
		limit = 10
	}
	return measureContextUsage(messages, len(snapshot.History), limit, conf.ContextTokens(), chatMaxOutputTokens), nil
}

func dropEmptyTrailingUser(messages []llminference.Message) []llminference.Message {
	if len(messages) == 0 {
		return messages
	}
	last := messages[len(messages)-1]
	if last.Role == "user" && strings.TrimSpace(last.Content) == "" {
		return messages[:len(messages)-1]
	}
	return messages
}

func measureContextUsage(messages []llminference.Message, historyMessages, historyLimit, contextLimit, outputReserve int) ContextUsage {
	usage := ContextUsage{
		HistoryMessages: historyMessages,
		HistoryLimit:    historyLimit,
		ContextLimit:    contextLimit,
		OutputReserve:   outputReserve,
	}
	for index, message := range messages {
		tokens := estimateTextTokens(message.Content) + messageOverheadTokens
		usage.PromptTokens += tokens
		if index == 0 && message.Role == "system" {
			usage.PersonaTokens += tokens
			continue
		}
		usage.HistoryTokens += tokens
	}
	if contextLimit > 0 && usage.PromptTokens+outputReserve > contextLimit {
		usage.Overflow = true
	}
	return usage
}

// estimateTextTokens 按字符粗算：汉字等非 ASCII 约 1 token，英文约 4 字符 1 token。
func estimateTextTokens(text string) int {
	ascii := 0
	tokens := 0
	for _, r := range text {
		if r <= 127 {
			ascii++
			continue
		}
		tokens++
	}
	tokens += (ascii + 3) / 4
	return tokens
}
