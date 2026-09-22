package llmapp

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	aibiz "backend/internal/biz/ai"
	llmbiz "backend/internal/biz/llm"
	"backend/model"
	"backend/pkg/conf"
	"backend/pkg/llminference"

	"gorm.io/gorm"
)

type fakeAIStore struct {
	cfg *model.AiUserConfig
}

func (s fakeAIStore) Raw() *gorm.DB { return nil }

func (s fakeAIStore) WithContext(context.Context) aibiz.AiStore {
	return s
}

func (s fakeAIStore) LoadOrCreateConfig(context.Context, uint) (*model.AiUserConfig, error) {
	return s.cfg, nil
}

func (s fakeAIStore) SaveConfig(context.Context, *model.AiUserConfig) error { return nil }

func (s fakeAIStore) UpdateConfig(
	context.Context,
	uint,
	func(*model.AiUserConfig) error,
) (*model.AiUserConfig, error) {
	return s.cfg, nil
}

func (s fakeAIStore) FindAllConfigs(context.Context) ([]model.AiUserConfig, error) { return nil, nil }

func (s fakeAIStore) GetUserDisplayName(context.Context, uint) string { return "" }

func TestChatAppliesBackendAgentContext(t *testing.T) {
	agents := mustJSONForServiceTest(t, []map[string]any{{
		"id":            "agent-1",
		"model_name":    "base:latest",
		"system_prompt": "server prompt",
		"persona":       "服务端人设",
	}})
	var capturedModel string
	var capturedMessages []llminference.Message
	svc := New(nil, Deps{
		UserID: func(context.Context) (uint, error) { return 7, nil },
		Inference: llminference.Config{
			BaseURL:      "http://inference.invalid",
			APIStyle:     "ollama",
			DefaultModel: "base:latest",
		},
		ModelManagement: conf.ModelManagement{AllowedBaseModels: []string{"base:latest"}},
		AIStore:         fakeAIStore{cfg: &model.AiUserConfig{AgentsJSON: agents, LorebooksJSON: "[]"}},
		ChatComplete: func(_ context.Context, model string, messages []llminference.Message, _ llminference.ChatOptions) (string, error) {
			capturedModel = model
			capturedMessages = messages
			return "hello", nil
		},
	})

	out, err := svc.Chat(context.Background(), llmbiz.PlatformChatInput{
		Model:   "stale-client-model",
		AgentID: "agent-1",
		Messages: []llmbiz.PlatformChatMessage{
			{Role: "system", Content: "client prompt"},
			{Role: "user", Content: "hi"},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !out.Success {
		t.Fatalf("out=%+v", out)
	}
	if capturedModel != "base:latest" {
		t.Fatalf("model=%q", capturedModel)
	}
	assertServerPrompt(t, capturedMessages)
}

func mustJSONForServiceTest(t *testing.T, value any) string {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func assertServerPrompt(t *testing.T, messages []llminference.Message) {
	t.Helper()
	if len(messages) != 2 || messages[0].Role != "system" {
		t.Fatalf("messages=%+v", messages)
	}
	if !strings.Contains(messages[0].Content, "server prompt") ||
		!strings.Contains(messages[0].Content, "服务端人设") ||
		strings.Contains(messages[0].Content, "client prompt") {
		t.Fatalf("system prompt=%q", messages[0].Content)
	}
}
