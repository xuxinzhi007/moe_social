package contentapp

import (
	"context"
	"strings"
	"testing"

	contentbiz "backend/internal/biz/content"
	llmbiz "backend/internal/biz/llm"
)

type fakeChatRunner struct {
	input llmbiz.PlatformChatInput
}

func (r *fakeChatRunner) Chat(_ context.Context, in llmbiz.PlatformChatInput) (llmbiz.PlatformChatOutcome, error) {
	r.input = in
	return llmbiz.PlatformChatOutcome{Success: true, Content: "generated content", Message: "ok"}, nil
}

func TestGenerateContentRunsBackendLLMWithContentPolicy(t *testing.T) {
	runner := &fakeChatRunner{}
	svc := New(runner)

	out, err := svc.GenerateContent(context.Background(), contentbiz.GenerateInput{
		Type:   "story",
		Prompt: " 写一个开头 ",
		Options: map[string]interface{}{
			"agent_id": "agent-1",
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if out.Content != "generated content" || out.Type != "story" || out.ID == "" || out.CreatedAt == "" {
		t.Fatalf("out=%+v", out)
	}
	if runner.input.AgentID != "agent-1" {
		t.Fatalf("agent id=%q", runner.input.AgentID)
	}
	if len(runner.input.Messages) != 1 || runner.input.Messages[0].Role != "user" || runner.input.Messages[0].Content != "写一个开头" {
		t.Fatalf("messages=%+v", runner.input.Messages)
	}
	if !strings.Contains(runner.input.ServerSystemPrompt, "故事创作") {
		t.Fatalf("system prompt=%q", runner.input.ServerSystemPrompt)
	}
}
