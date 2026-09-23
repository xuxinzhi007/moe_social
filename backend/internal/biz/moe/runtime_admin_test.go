package moebiz

import (
	"context"
	"testing"

	"backend/model"
)

func TestParseBotUserID_Invalid(t *testing.T) {
	if _, err := ParseBotUserID(""); err == nil {
		t.Fatal("expected error for empty")
	}
	if _, err := ParseBotUserID("abc"); err == nil {
		t.Fatal("expected error for non-numeric")
	}
}

func TestParseBotUserID_OK(t *testing.T) {
	id, err := ParseBotUserID("42")
	if err != nil || id != 42 {
		t.Fatalf("id=%d err=%v", id, err)
	}
}

func TestUpsertRuntimePreservesUnlimitedPostQuota(t *testing.T) {
	store := &runtimeAdminTestStore{}
	saved, err := UpsertRuntime(context.Background(), store, UpsertRuntimeParams{
		AgentKey:       "test_bot",
		BotUserID:      7,
		PostQuotaDaily: 0,
	})
	if err != nil {
		t.Fatalf("UpsertRuntime() error = %v", err)
	}
	if saved.PostQuotaDaily != 0 {
		t.Fatalf("PostQuotaDaily = %d, want 0 (unlimited)", saved.PostQuotaDaily)
	}
}

func TestUpsertRuntimeRejectsNegativePostQuota(t *testing.T) {
	store := &runtimeAdminTestStore{}
	if _, err := UpsertRuntime(context.Background(), store, UpsertRuntimeParams{
		AgentKey:       "test_bot",
		BotUserID:      7,
		PostQuotaDaily: -1,
	}); err == nil {
		t.Fatal("UpsertRuntime() error = nil, want negative quota rejected")
	}
}

type runtimeAdminTestStore struct {
	MoeStore
	saved model.MoeAgentRuntime
}

func (s *runtimeAdminTestStore) WithContext(context.Context) MoeStore {
	return s
}

func (s *runtimeAdminTestStore) UpsertRuntime(_ context.Context, runtime *model.MoeAgentRuntime) error {
	s.saved = *runtime
	return nil
}

func (s *runtimeAdminTestStore) MarkUserAsBot(context.Context, uint, string) error {
	return nil
}

func (s *runtimeAdminTestStore) GetRuntimeByAgentKey(context.Context, string) (model.MoeAgentRuntime, error) {
	return s.saved, nil
}
