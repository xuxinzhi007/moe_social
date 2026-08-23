package llminference

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestChatUsesResponsesAPIForGPTModels(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/responses" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		body, _ := io.ReadAll(r.Body)
		if !strings.Contains(string(body), `"instructions":"keep it short"`) {
			t.Fatalf("request missing instructions: %s", body)
		}
		_, _ = w.Write([]byte(`{"output_text":"hello"}`))
	}))
	defer server.Close()

	reply, err := Chat(context.Background(), Config{BaseURL: server.URL, APIStyle: APIOpenAI}, "gpt-5.3-codex", []Message{
		{Role: "system", Content: "keep it short"},
		{Role: "user", Content: "hi"},
	}, ChatOptions{})
	if err != nil {
		t.Fatalf("Chat() error = %v", err)
	}
	if reply != "hello" {
		t.Fatalf("Chat() reply = %q", reply)
	}
}

func TestChatStreamUsesResponsesAPIForGPTModels(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = w.Write([]byte("data: {\"type\":\"response.output_text.delta\",\"delta\":\"hel\"}\n\n"))
		_, _ = w.Write([]byte("data: {\"type\":\"response.output_text.delta\",\"delta\":\"lo\"}\n\n"))
	}))
	defer server.Close()

	var chunks strings.Builder
	reply, err := ChatStream(context.Background(), Config{BaseURL: server.URL, APIStyle: APIOpenAI}, "gpt-5.3-codex", []Message{{Role: "user", Content: "hi"}}, ChatOptions{}, func(chunk string) error {
		chunks.WriteString(chunk)
		return nil
	})
	if err != nil {
		t.Fatalf("ChatStream() error = %v", err)
	}
	if reply != "hello" || chunks.String() != "hello" {
		t.Fatalf("reply = %q, chunks = %q", reply, chunks.String())
	}
}
