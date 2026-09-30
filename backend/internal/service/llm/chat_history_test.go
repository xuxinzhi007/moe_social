package llmapp

import (
	"context"
	"errors"
	"strconv"
	"testing"

	llmbiz "backend/internal/biz/llm"
	"backend/model"
	"backend/pkg/llminference"

	"gorm.io/gorm"
)

func chatHistoryUser(id int) context.Context {
	return context.WithValue(context.Background(), "userId", strconv.Itoa(id))
}

func TestChatHistoryBelongsToActorAndDeletesCascade(t *testing.T) {
	svc := New(nil, Deps{UserID: chatHistoryUserID, ModelStore: newFakeChatHistoryStore()})
	ctx := chatHistoryUser(1)
	session, err := svc.UpsertChatSession(ctx, llmbiz.ChatSessionInput{
		SessionID: "session-1",
		AgentID:   "agent-1",
		Title:     "第一轮聊天",
		Model:     "base:latest",
	})
	if err != nil {
		t.Fatal(err)
	}
	if session.UserID != 1 || session.AgentID != "agent-1" || session.Title != "第一轮聊天" {
		t.Fatalf("session=%+v", session)
	}
	if _, err = svc.UpsertChatMessage(ctx, llmbiz.ChatMessageInput{
		SessionID:   "session-1",
		SourceMsgID: "msg-1",
		Role:        "user",
		Content:     "你好",
		Model:       "base:latest",
	}); err != nil {
		t.Fatal(err)
	}
	if _, err = svc.UpsertChatMessage(ctx, llmbiz.ChatMessageInput{
		SessionID:   "session-1",
		SourceMsgID: "msg-2",
		Role:        "assistant",
		Content:     "你好呀",
		Model:       "base:latest",
	}); err != nil {
		t.Fatal(err)
	}

	sessions, err := svc.ListChatSessions(ctx, "agent-1", 10)
	if err != nil || len(sessions) != 1 {
		t.Fatalf("sessions=%+v err=%v", sessions, err)
	}
	otherSessions, err := svc.ListChatSessions(chatHistoryUser(2), "agent-1", 10)
	if err != nil || len(otherSessions) != 0 {
		t.Fatalf("other sessions=%+v err=%v", otherSessions, err)
	}
	messages, err := svc.ListChatMessages(ctx, "session-1", 10)
	if err != nil || len(messages) != 2 {
		t.Fatalf("messages=%+v err=%v", messages, err)
	}

	if _, err = svc.UpsertChatSession(chatHistoryUser(2), llmbiz.ChatSessionInput{
		SessionID: "session-other",
		AgentID:   "agent-1",
		Title:     "另一账号",
	}); err != nil {
		t.Fatal(err)
	}

	if err = svc.DeleteChatSession(ctx, "session-1"); err != nil {
		t.Fatal(err)
	}
	sessions, err = svc.ListChatSessions(ctx, "agent-1", 10)
	if err != nil || len(sessions) != 0 {
		t.Fatalf("deleted sessions=%+v err=%v", sessions, err)
	}
	messages, err = svc.ListChatMessages(ctx, "session-1", 10)
	if err != nil || len(messages) != 0 {
		t.Fatalf("deleted messages=%+v err=%v", messages, err)
	}
	otherSessions, err = svc.ListChatSessions(chatHistoryUser(2), "agent-1", 10)
	if err != nil || len(otherSessions) != 1 || otherSessions[0].SessionID != "session-other" {
		t.Fatalf("other sessions after delete=%+v err=%v", otherSessions, err)
	}
}

func TestChatHistoryMessageUpsertIsIdempotent(t *testing.T) {
	svc := New(nil, Deps{UserID: chatHistoryUserID, ModelStore: newFakeChatHistoryStore()})
	ctx := chatHistoryUser(1)
	for _, content := range []string{"第一次", "重试后内容"} {
		if _, err := svc.UpsertChatMessage(ctx, llmbiz.ChatMessageInput{
			SessionID:   "session-1",
			SourceMsgID: "msg-1",
			Role:        "user",
			Content:     content,
		}); err != nil {
			t.Fatal(err)
		}
	}
	messages, err := svc.ListChatMessages(ctx, "session-1", 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(messages) != 1 || messages[0].Content != "重试后内容" {
		t.Fatalf("messages=%+v", messages)
	}
	if err = svc.DeleteChatMessage(ctx, "msg-1"); err != nil {
		t.Fatal(err)
	}
	messages, err = svc.ListChatMessages(ctx, "session-1", 10)
	if err != nil || len(messages) != 0 {
		t.Fatalf("deleted message=%+v err=%v", messages, err)
	}
}

func TestPlatformChatPersistsUserAndAssistantMessages(t *testing.T) {
	store := newFakeChatHistoryStore()
	svc := New(nil, Deps{
		UserID:     chatHistoryUserID,
		ModelStore: store,
		Inference: llminference.Config{
			BaseURL:      "http://inference.invalid",
			APIStyle:     "ollama",
			DefaultModel: "base:latest",
		},
		ChatComplete: func(
			context.Context,
			string,
			[]llminference.Message,
			llminference.ChatOptions,
		) (string, error) {
			return "你好呀", nil
		},
	})
	outcome, err := svc.Chat(chatHistoryUser(1), llmbiz.PlatformChatInput{
		Model:       "base:latest",
		SessionId:   "session-1",
		SourceMsgId: "msg-1",
		Messages: []llmbiz.PlatformChatMessage{
			{Role: "user", Content: "你好"},
		},
	})
	if err != nil || !outcome.Success {
		t.Fatalf("outcome=%+v err=%v", outcome, err)
	}
	messages, err := svc.ListChatMessages(chatHistoryUser(1), "session-1", 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(messages) != 2 {
		t.Fatalf("messages=%+v", messages)
	}
	if messages[0].SourceMsgID != "msg-1" || messages[0].Role != "user" {
		t.Fatalf("user message=%+v", messages[0])
	}
	if messages[1].SourceMsgID != "msg-1_assistant" || messages[1].Content != "你好呀" {
		t.Fatalf("assistant message=%+v", messages[1])
	}
}

func chatHistoryUserID(ctx context.Context) (uint, error) {
	raw, _ := ctx.Value("userId").(string)
	id, err := strconv.ParseUint(raw, 10, 64)
	if err != nil {
		return 0, err
	}
	return uint(id), nil
}

type fakeChatHistoryStore struct {
	sessions []model.AiChatSession
	messages []model.AiChatMessage
	nextID   uint
}

func newFakeChatHistoryStore() *fakeChatHistoryStore {
	return &fakeChatHistoryStore{nextID: 1}
}

func (s *fakeChatHistoryStore) Get(context.Context, uint, string) (model.LLMManagedModel, error) {
	return model.LLMManagedModel{}, gorm.ErrRecordNotFound
}

func (s *fakeChatHistoryStore) List(context.Context, uint) ([]model.LLMManagedModel, error) {
	return nil, nil
}

func (s *fakeChatHistoryStore) ByName(context.Context, string) (model.LLMManagedModel, error) {
	return model.LLMManagedModel{}, gorm.ErrRecordNotFound
}

func (s *fakeChatHistoryStore) Reserve(
	context.Context,
	uint,
	string,
	func(*model.LLMManagedModel, map[string]any, int64, int64) error,
) (model.LLMManagedModel, error) {
	return model.LLMManagedModel{}, errors.New("not implemented")
}

func (s *fakeChatHistoryStore) Finish(context.Context, *model.LLMManagedModel, bool) error {
	return errors.New("not implemented")
}

func (s *fakeChatHistoryStore) SaveIntent(context.Context, *model.LLMManagedModel, string) error {
	return errors.New("not implemented")
}

func (s *fakeChatHistoryStore) ListChatSessions(
	_ context.Context,
	userID uint,
	agentID string,
	_ int,
) ([]model.AiChatSession, error) {
	rows := []model.AiChatSession{}
	for _, session := range s.sessions {
		if session.UserID != userID {
			continue
		}
		if agentID != "" && session.AgentID != agentID {
			continue
		}
		rows = append(rows, session)
	}
	return rows, nil
}

func (s *fakeChatHistoryStore) ListChatMessages(
	_ context.Context,
	userID uint,
	sessionID string,
	_ int,
) ([]model.AiChatMessage, error) {
	rows := []model.AiChatMessage{}
	for _, message := range s.messages {
		if message.UserID == userID && message.SessionID == sessionID {
			rows = append(rows, message)
		}
	}
	return rows, nil
}

func (s *fakeChatHistoryStore) UpsertChatSession(
	_ context.Context,
	userID uint,
	input llmbiz.ChatSessionInput,
) (model.AiChatSession, error) {
	for i := range s.sessions {
		if s.sessions[i].UserID == userID && s.sessions[i].SessionID == input.SessionID {
			if input.AgentID != "" {
				s.sessions[i].AgentID = input.AgentID
			}
			if input.Title != "" {
				s.sessions[i].Title = input.Title
			}
			if input.Model != "" {
				s.sessions[i].Model = input.Model
			}
			return s.sessions[i], nil
		}
	}
	row := model.AiChatSession{
		ID:        s.nextID,
		UserID:    userID,
		SessionID: input.SessionID,
		AgentID:   input.AgentID,
		Title:     input.Title,
		Model:     input.Model,
	}
	s.nextID++
	s.sessions = append(s.sessions, row)
	return row, nil
}

func (s *fakeChatHistoryStore) DeleteChatSession(_ context.Context, userID uint, sessionID string) error {
	keptSessions := s.sessions[:0]
	for _, session := range s.sessions {
		if session.UserID == userID && session.SessionID == sessionID {
			continue
		}
		keptSessions = append(keptSessions, session)
	}
	s.sessions = keptSessions

	keptMessages := s.messages[:0]
	for _, message := range s.messages {
		if message.UserID == userID && message.SessionID == sessionID {
			continue
		}
		keptMessages = append(keptMessages, message)
	}
	s.messages = keptMessages
	return nil
}

func (s *fakeChatHistoryStore) UpsertChatMessage(
	_ context.Context,
	userID uint,
	input llmbiz.ChatMessageInput,
) (model.AiChatMessage, error) {
	for i := range s.messages {
		if s.messages[i].UserID == userID && s.messages[i].SourceMsgID == input.SourceMsgID {
			s.messages[i].Role = input.Role
			s.messages[i].Content = input.Content
			s.messages[i].Model = input.Model
			return s.messages[i], nil
		}
	}
	row := model.AiChatMessage{
		ID:          s.nextID,
		UserID:      userID,
		SessionID:   input.SessionID,
		SourceMsgID: input.SourceMsgID,
		Role:        input.Role,
		Content:     input.Content,
		Model:       input.Model,
		CreatedAt:   input.CreatedAt,
	}
	s.nextID++
	s.messages = append(s.messages, row)
	_, _ = s.UpsertChatSession(context.Background(), userID, llmbiz.ChatSessionInput{
		SessionID: input.SessionID,
		Model:     input.Model,
	})
	return row, nil
}

func (s *fakeChatHistoryStore) DeleteChatMessage(_ context.Context, userID uint, sourceMsgID string) error {
	kept := s.messages[:0]
	for _, message := range s.messages {
		if message.UserID == userID && message.SourceMsgID == sourceMsgID {
			continue
		}
		kept = append(kept, message)
	}
	s.messages = kept
	return nil
}
