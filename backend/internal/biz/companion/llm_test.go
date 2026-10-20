package companionbiz

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"backend/pkg/llminference"
)

func TestRelationshipGuidanceTracksRelationshipLevel(t *testing.T) {
	tests := []struct {
		name   string
		level  int
		want   string
		unwant string
	}{
		{name: "new", level: 1, want: "初识阶段", unwant: "主动创造共同回忆"},
		{name: "familiar", level: 4, want: "逐渐熟悉", unwant: "初识阶段"},
		{name: "stable", level: 6, want: "稳定联系", unwant: "逐渐熟悉"},
		{name: "close", level: 8, want: "很习惯", unwant: "稳定联系"},
		{name: "intimate", level: 10, want: "关系亲近", unwant: "很习惯"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			prompt := buildSystemPrompt(&Profile{RelationshipLevel: tt.level}, nil, nil)
			if !strings.Contains(prompt, tt.want) {
				t.Fatalf("prompt does not contain %q: %s", tt.want, prompt)
			}
			if strings.Contains(prompt, tt.unwant) {
				t.Fatalf("prompt unexpectedly contains %q: %s", tt.unwant, prompt)
			}
		})
	}
}

func TestRelationshipGuidanceSetsHealthyBoundary(t *testing.T) {
	guidance := relationshipGuidance(&Profile{RelationshipLevel: 10})
	if !strings.Contains(guidance, "尊重") || !strings.Contains(guidance, "现实关系") {
		t.Fatalf("high-level guidance lacks boundaries: %s", guidance)
	}
}

func TestSystemPromptSeparatesConfirmedMemoryFromCandidates(t *testing.T) {
	prompt := buildSystemPrompt(
		&Profile{Name: "Mochi"},
		nil,
		[]Memory{
			{Content: "confirmed fact", UserConfirmed: true},
			{Content: "candidate fact"},
		},
	)
	if !strings.Contains(prompt, "confirmed fact") || !strings.Contains(prompt, "candidate fact") {
		t.Fatalf("prompt omitted memory content: %s", prompt)
	}
	if !strings.Contains(prompt, "[待用户确认的印象]") ||
		!strings.Contains(prompt, "回答用户“你记得什么”时可以自然提起") {
		t.Fatalf("prompt omitted candidate boundary: %s", prompt)
	}
}

func TestSystemPromptIncludesRelationshipEvents(t *testing.T) {
	prompt := buildSystemPromptWithRelationshipEvents(
		&Profile{Name: "Mochi"},
		nil,
		nil,
		[]RelationshipEvent{{Title: "第一次聊天", Content: "你们开始了第一次对话"}},
	)
	if !strings.Contains(prompt, "[最近的关系进展]") ||
		!strings.Contains(prompt, "第一次聊天：你们开始了第一次对话") {
		t.Fatalf("prompt omitted relationship event: %s", prompt)
	}
}

func TestUnfinishedTopicsStayOnCurrentTurn(t *testing.T) {
	messages := buildMessagesWithContext(
		&Profile{Name: "Mochi"},
		&State{Mood: 10, Energy: 10, MoodThought: "有点累"},
		nil,
		nil,
		nil,
		[]string{"下次继续聊我的旅行计划"},
		"",
		"在吗",
	)
	system := messages[0].Content
	if strings.Contains(system, "下次继续聊我的旅行计划") || strings.Contains(system, "当前场景") || strings.Contains(system, "有点累") {
		t.Fatalf("volatile context leaked into system prompt: %s", system)
	}
	last := messages[len(messages)-1]
	if last.Role != "user" || last.Content != "在吗" {
		t.Fatalf("user message = %#v", last)
	}
	note := messages[len(messages)-2]
	if note.Role != "system" || strings.Contains(note.Content, "下次继续聊我的旅行计划") || strings.Contains(note.Content, "情绪安抚") {
		t.Fatalf("turn note should not carry topic or scene: %#v", note)
	}
	if strings.Contains(messages[0].Content, "下次继续聊我的旅行计划") {
		t.Fatalf("topic leaked into system prompt: %s", messages[0].Content)
	}
}

func TestSystemPromptStaysPersonalChat(t *testing.T) {
	prompt := buildSystemPrompt(&Profile{Name: "啾啾", RelationshipLevel: 3}, nil, nil)
	for _, banned := range []string{"社区工具", "搜公开动态", "发动态", "[你自己会的事]"} {
		if strings.Contains(prompt, banned) {
			t.Fatalf("prompt still mentions community action %q", banned)
		}
	}
	for _, want := range []string{"不要编造名字", "用聊天记录后面那条时间说明回答"} {
		if !strings.Contains(prompt, want) {
			t.Fatalf("prompt missing %q", want)
		}
	}
}

func TestClockStaysOnCurrentTurn(t *testing.T) {
	profile := &Profile{Name: "啾啾", RelationshipLevel: 3}
	state := &State{MoodThought: "想聊天", ActivityLabel: "发呆"}
	history := []ChatLog{{
		Role:    "assistant",
		Content: "<think>先想很久</think>在的",
	}}
	messages := buildMessagesWithContext(profile, state, nil, history, nil, nil, "", "在吗")
	if strings.Contains(messages[0].Content, "现在是") || strings.Contains(messages[0].Content, "想聊天") || strings.Contains(messages[0].Content, "当前场景") {
		t.Fatalf("volatile context leaked into system prompt: %s", messages[0].Content)
	}
	if messages[1].Content != "在的" {
		t.Fatalf("history = %q", messages[1].Content)
	}
	note := messages[len(messages)-2]
	last := messages[len(messages)-1]
	if note.Role != "system" || !strings.Contains(note.Content, "现在是") || strings.Contains(note.Content, "想聊天") || strings.Contains(note.Content, "当前场景") {
		t.Fatalf("turn note = %#v", note)
	}
	if last.Role != "user" || last.Content != "在吗" {
		t.Fatalf("user message = %#v", last)
	}
}

func TestLegacyMessageBuilderRemainsCompatible(t *testing.T) {
	legacy := buildMessages(&Profile{Name: "Mochi"}, nil, nil, nil, "hello")
	current := buildMessagesWithRelationshipEvents(&Profile{Name: "Mochi"}, nil, nil, nil, nil, "hello")
	if len(legacy) != len(current) || legacy[0].Content != current[0].Content {
		t.Fatalf("legacy and current message builders diverged: legacy=%+v current=%+v", legacy, current)
	}
}

func TestTrimChatHistoryKeepsNewestBudget(t *testing.T) {
	history := []ChatLog{
		{Role: "user", Content: strings.Repeat("早", 200)},
		{Role: "assistant", Content: strings.Repeat("嗯", 200)},
		{Role: "user", Content: "只回答数字2"},
		{Role: "assistant", Content: "2"},
		{Role: "user", Content: "你现在在会什么"},
	}
	trimmed := trimChatHistory(history, 4, 20)
	if len(trimmed) != 3 || trimmed[0].Content != "只回答数字2" || trimmed[2].Content != "你现在在会什么" {
		t.Fatalf("trimmed = %#v", trimmed)
	}
}

func TestStreamChatFallsBackWhenProviderStreamEndsWithoutContent(t *testing.T) {
	var streamRequests int
	var nonStreamRequests int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var request struct {
			Stream bool `json:"stream"`
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		w.Header().Set("Content-Type", "application/json")
		if request.Stream {
			streamRequests++
			_, _ = w.Write([]byte("data: {\"choices\":[{\"delta\":{}}]}\n\ndata: [DONE]\n\n"))
			return
		}
		nonStreamRequests++
		_, _ = w.Write([]byte("{\"choices\":[{\"message\":{\"content\":\"我在，慢慢说。\"}}]}"))
	}))
	defer server.Close()

	var chunks []string
	reply, err := streamChat(
		context.Background(),
		llminference.Config{BaseURL: server.URL, DefaultModel: "test-model", Timeout: time.Second},
		"test-model",
		[]llminference.Message{{Role: "user", Content: "hello"}},
		func(chunk string) error {
			chunks = append(chunks, chunk)
			return nil
		},
		false,
	)
	if err != nil {
		t.Fatalf("streamChat() error = %v", err)
	}
	if reply != "我在，慢慢说。" {
		t.Fatalf("streamChat() reply = %q", reply)
	}
	if streamRequests != 1 || nonStreamRequests != 1 {
		t.Fatalf("requests = stream:%d non-stream:%d, want 1 each", streamRequests, nonStreamRequests)
	}
	if len(chunks) != 1 || chunks[0] != reply {
		t.Fatalf("chunks = %#v, want fallback reply", chunks)
	}
}

func TestStreamChatFallbackSurvivesCanceledStreamContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	var nonStreamRequests int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var request struct {
			Stream bool `json:"stream"`
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		w.Header().Set("Content-Type", "application/json")
		if request.Stream {
			cancel()
			_, _ = w.Write([]byte("not-json\n"))
			return
		}
		nonStreamRequests++
		_, _ = w.Write([]byte("{\"choices\":[{\"message\":{\"content\":\"我在，刚刚线路抖了一下。\"}}]}"))
	}))
	defer server.Close()

	var chunks []string
	reply, err := streamChat(
		ctx,
		llminference.Config{BaseURL: server.URL, DefaultModel: "test-model", Timeout: time.Second},
		"test-model",
		[]llminference.Message{{Role: "user", Content: "hello"}},
		func(chunk string) error {
			chunks = append(chunks, chunk)
			return nil
		},
		false,
	)
	if err != nil {
		t.Fatalf("streamChat() error = %v", err)
	}
	if reply != "我在，刚刚线路抖了一下。" {
		t.Fatalf("streamChat() reply = %q", reply)
	}
	if nonStreamRequests != 1 {
		t.Fatalf("nonStreamRequests = %d, want 1", nonStreamRequests)
	}
	if len(chunks) != 1 || chunks[0] != reply {
		t.Fatalf("chunks = %#v, want fallback reply", chunks)
	}
}

func TestStreamChatThinkDoesNotCapPrediction(t *testing.T) {
	var body map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			_, _ = w.Write([]byte(`{"models":[{"name":"qwen3.5:9b","capabilities":["thinking"]}]}`))
			return
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		_, _ = w.Write([]byte("{\"message\":{\"thinking\":\"先想\",\"content\":\"好\"},\"done\":true}\n"))
	}))
	defer server.Close()

	reply, err := streamChat(
		context.Background(),
		llminference.Config{BaseURL: server.URL, APIStyle: llminference.APIOllama, DefaultModel: "qwen3.5:9b", Timeout: time.Second},
		"qwen3.5:9b",
		[]llminference.Message{{Role: "user", Content: "你好"}},
		func(string) error { return nil },
		true,
	)
	if err != nil {
		t.Fatalf("streamChat() error = %v", err)
	}
	if reply != "好" {
		t.Fatalf("reply = %q", reply)
	}
	if body["think"] != true {
		t.Fatalf("think = %#v", body["think"])
	}
	options, _ := body["options"].(map[string]any)
	if _, ok := options["num_predict"]; ok {
		t.Fatalf("options = %#v, want no num_predict while thinking", options)
	}
}

func TestStreamChatSeparatesInlineThink(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			_, _ = w.Write([]byte(`{"models":[{"name":"lfm","capabilities":["thinking"]}]}`))
			return
		}
		_, _ = w.Write([]byte(strings.Join([]string{
			`{"message":{"content":"<think>先"},"done":false}`,
			`{"message":{"content":"想</think>你好"},"done":true}`,
		}, "\n") + "\n"))
	}))
	defer server.Close()

	var answer, thought strings.Builder
	ctx := WithThinkingHandler(context.Background(), func(chunk string) error {
		thought.WriteString(chunk)
		return nil
	})
	ctx = WithChatThink(ctx, true)
	reply, err := streamChat(
		ctx,
		llminference.Config{BaseURL: server.URL, APIStyle: llminference.APIOllama, DefaultModel: "lfm", Timeout: time.Second},
		"lfm",
		[]llminference.Message{{Role: "user", Content: "你好"}},
		func(chunk string) error {
			answer.WriteString(chunk)
			return nil
		},
		true,
	)
	if err != nil {
		t.Fatalf("streamChat() error = %v", err)
	}
	if reply != "你好" || answer.String() != "你好" {
		t.Fatalf("reply = %q answer = %q", reply, answer.String())
	}
	if thought.String() != "先想" {
		t.Fatalf("thinking = %q", thought.String())
	}
}
