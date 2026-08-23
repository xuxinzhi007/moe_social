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
	if !strings.Contains(prompt, "[unconfirmed memory candidates]") {
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

func TestSystemPromptIncludesUnfinishedTopics(t *testing.T) {
	prompt := buildSystemPromptWithContext(
		&Profile{Name: "Mochi"},
		nil,
		nil,
		nil,
		[]string{"下次继续聊我的旅行计划"},
	)
	if !strings.Contains(prompt, "[未完成话题]") ||
		!strings.Contains(prompt, "下次继续聊我的旅行计划") {
		t.Fatalf("prompt omitted unfinished topic: %s", prompt)
	}
}

func TestLegacyMessageBuilderRemainsCompatible(t *testing.T) {
	legacy := buildMessages(&Profile{Name: "Mochi"}, nil, nil, nil, "hello")
	current := buildMessagesWithRelationshipEvents(&Profile{Name: "Mochi"}, nil, nil, nil, nil, "hello")
	if len(legacy) != len(current) || legacy[0].Content != current[0].Content {
		t.Fatalf("legacy and current message builders diverged: legacy=%+v current=%+v", legacy, current)
	}
}

func TestSceneGuidanceSupportsComfortAndRepair(t *testing.T) {
	guidance := sceneGuidance(
		time.Date(2026, time.December, 25, 23, 0, 0, 0, time.Local),
		&State{Mood: 30, Energy: 20},
	)
	for _, want := range []string{"情绪安抚", "承接用户的感受", "具体道歉", "圣诞节"} {
		if !strings.Contains(guidance, want) {
			t.Fatalf("scene guidance does not contain %q: %s", want, guidance)
		}
	}
}

func TestHolidayLabelOnlyUsesSupportedFixedDates(t *testing.T) {
	if got := holidayLabel(time.Date(2026, time.July, 7, 12, 0, 0, 0, time.Local)); got != "" {
		t.Fatalf("holidayLabel() = %q, want empty for unsupported date", got)
	}
	if got := holidayLabel(time.Date(2026, time.October, 1, 12, 0, 0, 0, time.Local)); got != "国庆节" {
		t.Fatalf("holidayLabel() = %q, want 国庆节", got)
	}
}

func TestSceneGuidanceMapsUserSceneIds(t *testing.T) {
	guidance := sceneGuidance(time.Date(2026, time.August, 3, 14, 0, 0, 0, time.Local), nil, "study")
	if !strings.Contains(guidance, "专注学习") || !strings.Contains(guidance, "小步骤") {
		t.Fatalf("scene guidance = %s", guidance)
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
