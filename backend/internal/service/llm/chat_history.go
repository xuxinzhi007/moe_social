package llmapp

import (
	"context"

	llmbiz "backend/internal/biz/llm"
	"backend/model"
)

func (s *AppService) ListChatSessions(
	ctx context.Context,
	agentID string,
	limit int,
) ([]model.AiChatSession, error) {
	id, err := s.actor(ctx, true)
	if err != nil {
		return nil, err
	}
	return llmbiz.ListChatSessions(ctx, s.chatHistoryStore(), id, agentID, limit)
}

func (s *AppService) ListChatMessages(
	ctx context.Context,
	sessionID string,
	limit int,
) ([]model.AiChatMessage, error) {
	id, err := s.actor(ctx, true)
	if err != nil {
		return nil, err
	}
	return llmbiz.ListChatMessages(ctx, s.chatHistoryStore(), id, sessionID, limit)
}

func (s *AppService) UpsertChatSession(
	ctx context.Context,
	input llmbiz.ChatSessionInput,
) (model.AiChatSession, error) {
	id, err := s.actor(ctx, true)
	if err != nil {
		return model.AiChatSession{}, err
	}
	return llmbiz.UpsertChatSession(ctx, s.chatHistoryStore(), id, input)
}

func (s *AppService) DeleteChatSession(ctx context.Context, sessionID string) error {
	id, err := s.actor(ctx, true)
	if err != nil {
		return err
	}
	return llmbiz.DeleteChatSession(ctx, s.chatHistoryStore(), id, sessionID)
}

func (s *AppService) UpsertChatMessage(
	ctx context.Context,
	input llmbiz.ChatMessageInput,
) (model.AiChatMessage, error) {
	id, err := s.actor(ctx, true)
	if err != nil {
		return model.AiChatMessage{}, err
	}
	return llmbiz.UpsertChatMessage(ctx, s.chatHistoryStore(), id, input)
}

func (s *AppService) DeleteChatMessage(ctx context.Context, sourceMsgID string) error {
	id, err := s.actor(ctx, true)
	if err != nil {
		return err
	}
	return llmbiz.DeleteChatMessage(ctx, s.chatHistoryStore(), id, sourceMsgID)
}

func (s *AppService) chatHistoryStore() llmbiz.ChatHistoryStore {
	if store, ok := s.deps.ModelStore.(llmbiz.ChatHistoryStore); ok {
		return store
	}
	return nil
}
