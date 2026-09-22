package llmbiz

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"backend/model"
)

var (
	ErrChatSessionRequired = errors.New("chat session required")
	ErrChatMessageRequired = errors.New("chat message required")
	ErrChatRoleInvalid     = errors.New("chat role invalid")
)

// ChatHistoryStore persists user-owned AI chat sessions and messages.
type ChatHistoryStore interface {
	ListChatSessions(ctx context.Context, userID uint, agentID string, limit int) ([]model.AiChatSession, error)
	ListChatMessages(ctx context.Context, userID uint, sessionID string, limit int) ([]model.AiChatMessage, error)
	UpsertChatSession(ctx context.Context, userID uint, input ChatSessionInput) (model.AiChatSession, error)
	DeleteChatSession(ctx context.Context, userID uint, sessionID string) error
	UpsertChatMessage(ctx context.Context, userID uint, input ChatMessageInput) (model.AiChatMessage, error)
	DeleteChatMessage(ctx context.Context, userID uint, sourceMsgID string) error
}

type ChatSessionInput struct {
	SessionID string
	AgentID   string
	Title     string
	Model     string
}

type ChatMessageInput struct {
	SessionID   string
	SourceMsgID string
	Role        string
	Content     string
	Model       string
	CreatedAt   time.Time
}

// ListChatSessions returns recent user-owned AI chat sessions.
func ListChatSessions(
	ctx context.Context,
	store ChatHistoryStore,
	userID uint,
	agentID string,
	limit int,
) ([]model.AiChatSession, error) {
	if store == nil {
		return nil, fmt.Errorf("list chat sessions: %w", ErrChatSessionRequired)
	}
	return store.ListChatSessions(ctx, userID, strings.TrimSpace(agentID), clampChatHistoryLimit(limit, 50, 200))
}

// ListChatMessages returns messages for a user-owned AI chat session.
func ListChatMessages(
	ctx context.Context,
	store ChatHistoryStore,
	userID uint,
	sessionID string,
	limit int,
) ([]model.AiChatMessage, error) {
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return nil, ErrChatSessionRequired
	}
	if store == nil {
		return nil, fmt.Errorf("list chat messages %s: %w", sessionID, ErrChatSessionRequired)
	}
	return store.ListChatMessages(ctx, userID, sessionID, clampChatHistoryLimit(limit, 200, 500))
}

// UpsertChatSession creates or updates a user-owned AI chat session.
func UpsertChatSession(
	ctx context.Context,
	store ChatHistoryStore,
	userID uint,
	input ChatSessionInput,
) (model.AiChatSession, error) {
	input.SessionID = strings.TrimSpace(input.SessionID)
	input.AgentID = strings.TrimSpace(input.AgentID)
	input.Title = strings.TrimSpace(input.Title)
	input.Model = strings.TrimSpace(input.Model)
	if input.SessionID == "" {
		return model.AiChatSession{}, ErrChatSessionRequired
	}
	if store == nil {
		return model.AiChatSession{}, fmt.Errorf("upsert chat session %s: %w", input.SessionID, ErrChatSessionRequired)
	}
	return store.UpsertChatSession(ctx, userID, input)
}

// DeleteChatSession deletes a user-owned AI chat session and its messages.
func DeleteChatSession(ctx context.Context, store ChatHistoryStore, userID uint, sessionID string) error {
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return ErrChatSessionRequired
	}
	if store == nil {
		return fmt.Errorf("delete chat session %s: %w", sessionID, ErrChatSessionRequired)
	}
	return store.DeleteChatSession(ctx, userID, sessionID)
}

// UpsertChatMessage creates or updates a message under a user-owned AI chat session.
func UpsertChatMessage(
	ctx context.Context,
	store ChatHistoryStore,
	userID uint,
	input ChatMessageInput,
) (model.AiChatMessage, error) {
	input.SessionID = strings.TrimSpace(input.SessionID)
	input.SourceMsgID = strings.TrimSpace(input.SourceMsgID)
	input.Role = strings.TrimSpace(input.Role)
	input.Content = strings.TrimSpace(input.Content)
	input.Model = strings.TrimSpace(input.Model)
	if input.SessionID == "" {
		return model.AiChatMessage{}, ErrChatSessionRequired
	}
	if input.Role != "user" && input.Role != "assistant" && input.Role != "system" {
		return model.AiChatMessage{}, ErrChatRoleInvalid
	}
	if input.Content == "" {
		return model.AiChatMessage{}, ErrChatMessageRequired
	}
	if input.CreatedAt.IsZero() {
		input.CreatedAt = time.Now()
	}
	if store == nil {
		return model.AiChatMessage{}, fmt.Errorf("upsert chat message %s: %w", input.SessionID, ErrChatMessageRequired)
	}
	return store.UpsertChatMessage(ctx, userID, input)
}

// DeleteChatMessage deletes one user-owned AI chat message by client message ID.
func DeleteChatMessage(ctx context.Context, store ChatHistoryStore, userID uint, sourceMsgID string) error {
	sourceMsgID = strings.TrimSpace(sourceMsgID)
	if sourceMsgID == "" {
		return ErrChatMessageRequired
	}
	if store == nil {
		return fmt.Errorf("delete chat message %s: %w", sourceMsgID, ErrChatMessageRequired)
	}
	return store.DeleteChatMessage(ctx, userID, sourceMsgID)
}

func clampChatHistoryLimit(value, fallback, maximum int) int {
	if value <= 0 {
		return fallback
	}
	if value > maximum {
		return maximum
	}
	return value
}
