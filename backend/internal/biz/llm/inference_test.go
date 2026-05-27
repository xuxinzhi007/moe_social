package llmbiz_test

import (
	"context"
	"testing"

	llmbiz "backend/internal/biz/llm"
	"backend/pkg/llminference"
)

func TestPostChatCompletionEmptyBaseURL(t *testing.T) {
	_, err := llmbiz.PostChatCompletion(context.Background(), llminference.Config{}, "m", []llmbiz.ChatMessage{
		{Role: "user", Content: "hi"},
	}, llmbiz.ChatOptions{})
	if err == nil {
		t.Fatal("expected error for empty base url")
	}
}
