package companionbiz

import (
	"context"
	"strings"
	"testing"

	"backend/model"
	"backend/pkg/llminference"
)

func TestEstimateTextTokensCountsHanAsOne(t *testing.T) {
	if got := estimateTextTokens("你好世界"); got != 4 {
		t.Fatalf("estimateTextTokens(你好世界) = %d, want 4", got)
	}
	if got := estimateTextTokens("hello"); got != 2 {
		t.Fatalf("estimateTextTokens(hello) = %d, want 2", got)
	}
}

func TestMeasureContextUsageMarksOverflow(t *testing.T) {
	messages := []llminference.Message{
		{Role: "system", Content: strings.Repeat("人", 20)},
		{Role: "user", Content: "你好"},
	}
	usage := measureContextUsage(messages, 1, 10, 30, 8)
	if usage.PersonaTokens <= usage.HistoryTokens {
		t.Fatalf("persona tokens = %d, history tokens = %d", usage.PersonaTokens, usage.HistoryTokens)
	}
	if !usage.Overflow {
		t.Fatalf("usage = %+v, want overflow", usage)
	}
}

func TestChatContextUsageKeepsRecentHistoryOnly(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")
	engine.MaxHistoryTurns = 10
	for index := 0; index < 12; index++ {
		if err := store.AppendChatLog(context.Background(), &model.CompanionChatLog{
			UserID:  7,
			Role:    "user",
			Content: "你好",
		}); err != nil {
			t.Fatalf("AppendChatLog() error = %v", err)
		}
	}

	usage, err := engine.ChatContextUsage(context.Background(), 7)
	if err != nil {
		t.Fatalf("ChatContextUsage() error = %v", err)
	}
	if usage.HistoryMessages != 10 || usage.HistoryLimit != 10 {
		t.Fatalf("history = %d/%d, want 10/10", usage.HistoryMessages, usage.HistoryLimit)
	}
	if usage.PersonaTokens <= 0 || usage.PromptTokens < usage.PersonaTokens {
		t.Fatalf("usage = %+v, want persona inside prompt", usage)
	}
	if usage.ContextLimit <= 0 {
		t.Fatal("context limit is empty")
	}
}
