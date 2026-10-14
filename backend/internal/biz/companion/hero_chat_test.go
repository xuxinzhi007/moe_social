package companionbiz

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	"unicode/utf8"

	lifebiz "backend/internal/biz/life"
	"backend/model"
	"backend/pkg/llminference"
)

func heroChatTestConfig(baseURL string) llminference.Config {
	return llminference.Config{
		BaseURL:      baseURL,
		APIStyle:     llminference.APIOpenAI,
		Timeout:      time.Second,
		DefaultModel: "test",
	}
}

func newHeroChatInference(reply string, captured *string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if captured != nil {
			body, _ := io.ReadAll(r.Body)
			*captured = string(body)
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]string{"role": "assistant", "content": reply}},
			},
		})
	}))
}

func TestHeroChatRejectsUnknownSlug(t *testing.T) {
	engine := NewEngine(newFakeStore(), nil, llminference.Config{}, "")
	engine.SetHeroBondResolver(func(context.Context, uint, string) (int, error) {
		return HeroChatBondRequired, nil
	})

	_, err := engine.HeroChat(context.Background(), 7, "ghost", "你好")
	if !errors.Is(err, ErrHeroNotFound) {
		t.Fatalf("HeroChat() error = %v, want ErrHeroNotFound", err)
	}
}

func TestHeroChatRejectsLowBond(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")
	engine.SetHeroBondResolver(func(context.Context, uint, string) (int, error) {
		return HeroChatBondRequired - 1, nil
	})

	_, err := engine.HeroChat(context.Background(), 7, lifebiz.HeroSlugXiaoxing, "你好")
	if !errors.Is(err, ErrHeroChatBondTooLow) {
		t.Fatalf("HeroChat() error = %v, want ErrHeroChatBondTooLow", err)
	}
	if len(store.logs) != 0 {
		t.Fatalf("chat logs = %+v, want nothing persisted when bond is too low", store.logs)
	}
}

func TestHeroChatRejectsMissingBondResolver(t *testing.T) {
	engine := NewEngine(newFakeStore(), nil, llminference.Config{}, "")

	_, err := engine.HeroChat(context.Background(), 7, lifebiz.HeroSlugXiaoxing, "你好")
	if err == nil || !strings.Contains(err.Error(), "bond resolver") {
		t.Fatalf("HeroChat() error = %v, want bond resolver not configured", err)
	}
}

func TestHeroChatPersistsHeroScopedTurnWithTruncation(t *testing.T) {
	store := newFakeStore()
	longReply := strings.Repeat("星", HeroChatMaxReplyRunes+50)
	server := newHeroChatInference(longReply, nil)
	defer server.Close()

	engine := NewEngine(store, nil, heroChatTestConfig(server.URL), "test")
	engine.SetHeroBondResolver(func(context.Context, uint, string) (int, error) {
		return HeroChatBondRequired, nil
	})

	reply, err := engine.HeroChat(context.Background(), 7, lifebiz.HeroSlugXiaoxing, "今天过得怎么样")
	if err != nil {
		t.Fatalf("HeroChat() error = %v", err)
	}
	if utf8.RuneCountInString(reply) != HeroChatMaxReplyRunes {
		t.Fatalf("reply runes = %d, want hard truncation at %d",
			utf8.RuneCountInString(reply), HeroChatMaxReplyRunes)
	}

	if len(store.logs) != 2 {
		t.Fatalf("chat logs = %+v, want user and assistant rows", store.logs)
	}
	for _, entry := range store.logs {
		if entry.HeroID != lifebiz.HeroSlugXiaoxing {
			t.Fatalf("chat log = %+v, want hero scope %q", entry, lifebiz.HeroSlugXiaoxing)
		}
	}
	if len(store.memoryJobs) != 0 {
		t.Fatalf("memory jobs = %+v, want none for hero chat (M1)", store.memoryJobs)
	}

	// D1 边界：英雄闲聊不得进入主伙伴历史。
	accountHistory, err := store.ListRecentChatLogs(context.Background(), 7, 10)
	if err != nil {
		t.Fatalf("ListRecentChatLogs() error = %v", err)
	}
	if len(accountHistory) != 0 {
		t.Fatalf("account history = %+v, want empty after hero chat", accountHistory)
	}
}

func TestHeroChatPromptIncludesWorldContext(t *testing.T) {
	store := newFakeStore()
	store.memories = []model.CompanionMemory{
		{UserID: 7, HeroID: lifebiz.HeroSlugXiaoxing, MemoryType: "fact", Content: "TA送过三次花"},
	}
	lifeStore := &fakeLifeStore{
		entities: []model.LifeEntity{{
			ID:            9,
			Name:          "小星",
			HeroSlug:      lifebiz.HeroSlugXiaoxing,
			CurrentAction: "walking",
			Mood:          80,
			Energy:        70,
			IsAlive:       true,
		}},
		events: []model.LifeEventLog{{
			EntityID:    9,
			EventType:   "interaction",
			Description: "小星帮新居民找到了营地",
		}},
	}

	var captured string
	server := newHeroChatInference("我很好呀", &captured)
	defer server.Close()

	engine := NewEngine(store, lifeStore, heroChatTestConfig(server.URL), "test")
	engine.SetHeroBondResolver(func(context.Context, uint, string) (int, error) {
		return HeroChatBondRequired, nil
	})

	if _, err := engine.HeroChat(context.Background(), 7, lifebiz.HeroSlugXiaoxing, "在干嘛"); err != nil {
		t.Fatalf("HeroChat() error = %v", err)
	}
	for _, want := range []string{"小星", "星星向导", "散步", "小星帮新居民找到了营地", "TA送过三次花", "300 字以内"} {
		if !strings.Contains(captured, want) {
			t.Fatalf("prompt missing %q:\n%s", want, captured)
		}
	}
}
