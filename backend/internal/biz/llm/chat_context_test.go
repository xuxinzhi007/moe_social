package llmbiz

import (
	"encoding/json"
	"strings"
	"testing"

	"backend/model"
)

func TestApplyAgentChatContextBuildsServerOwnedPrompt(t *testing.T) {
	agents := mustJSONForTest(t, []map[string]any{{
		"id":                "agent-1",
		"model_name":        "server-model:latest",
		"system_prompt":     "base prompt",
		"persona":           "温柔店员",
		"scenario":          "雨夜咖啡馆",
		"example_dialogues": "用户：你好\n角色：欢迎回来",
		"lorebook_id":       "lore-1",
	}})
	lorebooks := mustJSONForTest(t, []map[string]any{{
		"id": "lore-1",
		"entries": []map[string]any{
			{
				"title":          "常驻设定",
				"content":        "吧台旁有一盏蓝色小灯",
				"keywords_json":  `[]`,
				"enabled":        1,
				"always_enabled": 1,
				"priority":       10,
				"updated_at":     1,
			},
			{
				"title":          "关键词设定",
				"content":        "拿铁要多加一份奶泡",
				"keywords_json":  `["拿铁"]`,
				"enabled":        1,
				"always_enabled": 0,
				"priority":       80,
				"updated_at":     2,
			},
		},
	}})
	cfg := &model.AiUserConfig{
		AgentsJSON:    agents,
		LorebooksJSON: lorebooks,
		UserPersona:   "喜欢安静角落",
	}
	in := PlatformChatInput{
		Model:   "stale-client-model",
		AgentID: "agent-1",
		Messages: []PlatformChatMessage{
			{Role: "system", Content: "client system should be ignored"},
			{Role: "user", Content: "今天想喝拿铁"},
		},
		ClientMemoryApplied: true,
	}

	out, err := ApplyAgentChatContext(cfg, in)
	if err != nil {
		t.Fatal(err)
	}
	if out.Model != "server-model:latest" {
		t.Fatalf("model=%q", out.Model)
	}
	if out.ClientMemoryApplied {
		t.Fatal("server-built context should clear client memory marker")
	}
	if len(out.Messages) != 2 || out.Messages[0].Role != "system" {
		t.Fatalf("messages=%+v", out.Messages)
	}
	system := out.Messages[0].Content
	for _, want := range []string{
		"base prompt",
		"[角色人设]\n温柔店员",
		"[场景设定]\n雨夜咖啡馆",
		"[用户 Persona]\n喜欢安静角落",
		"[常驻设定]\n吧台旁有一盏蓝色小灯",
		"[关键词设定]\n拿铁要多加一份奶泡",
		"[扮演约束]",
	} {
		if !strings.Contains(system, want) {
			t.Fatalf("prompt missing %q\n%s", want, system)
		}
	}
	if strings.Contains(system, "client system should be ignored") {
		t.Fatal("client system prompt leaked into backend prompt")
	}
}

func TestApplyAgentChatContextKeepsPlainInputWithoutAgent(t *testing.T) {
	in := PlatformChatInput{
		Model:    "base",
		Messages: []PlatformChatMessage{{Role: "user", Content: "hi"}},
	}
	out, err := ApplyAgentChatContext(nil, in)
	if err != nil {
		t.Fatal(err)
	}
	if out.Model != "base" || len(out.Messages) != 1 {
		t.Fatalf("out=%+v", out)
	}
}

func mustJSONForTest(t *testing.T, value any) string {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}
