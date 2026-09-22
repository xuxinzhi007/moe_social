package llmapp

import (
	"context"
	"strings"
	"time"

	llmbiz "backend/internal/biz/llm"
)

func (s *AppService) persistChatUserMessage(ctx context.Context, userID uint, in llmbiz.PlatformChatInput) error {
	if !shouldPersistPlatformChat(userID, in) {
		return nil
	}
	message := lastUserMessage(in.Messages)
	if strings.TrimSpace(message.Content) == "" {
		return nil
	}
	store := s.chatHistoryStore()
	if _, err := llmbiz.UpsertChatSession(ctx, store, userID, llmbiz.ChatSessionInput{
		SessionID: in.SessionId,
		AgentID:   in.AgentID,
		Model:     in.Model,
	}); err != nil {
		return err
	}
	_, err := llmbiz.UpsertChatMessage(ctx, store, userID, llmbiz.ChatMessageInput{
		SessionID:   in.SessionId,
		SourceMsgID: in.SourceMsgId,
		Role:        "user",
		Content:     message.Content,
		Model:       in.Model,
		CreatedAt:   time.Now(),
	})
	return err
}

func (s *AppService) persistChatAssistantMessage(
	ctx context.Context,
	userID uint,
	in llmbiz.PlatformChatInput,
	content string,
) error {
	if !shouldPersistPlatformChat(userID, in) {
		return nil
	}
	_, err := llmbiz.UpsertChatMessage(ctx, s.chatHistoryStore(), userID, llmbiz.ChatMessageInput{
		SessionID:   in.SessionId,
		SourceMsgID: assistantSourceMsgID(in.SourceMsgId),
		Role:        "assistant",
		Content:     content,
		Model:       in.Model,
		CreatedAt:   time.Now(),
	})
	return err
}

func shouldPersistPlatformChat(userID uint, in llmbiz.PlatformChatInput) bool {
	return userID != 0 &&
		strings.TrimSpace(in.SessionId) != "" &&
		strings.TrimSpace(in.SourceMsgId) != ""
}

func lastUserMessage(messages []llmbiz.PlatformChatMessage) llmbiz.PlatformChatMessage {
	for i := len(messages) - 1; i >= 0; i-- {
		if messages[i].Role == "user" {
			return messages[i]
		}
	}
	return llmbiz.PlatformChatMessage{}
}

func assistantSourceMsgID(userSourceMsgID string) string {
	return strings.TrimSpace(userSourceMsgID) + "_assistant"
}
