package llminference

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestOpenAIRequestIncludesTools(t *testing.T) {
	body := newOpenAIChatRequest("qwen", []Message{{Role: "user", Content: "hi"}}, ChatOptions{
		Tools: []Tool{{
			Name:        "post_search",
			Description: "search",
			Parameters:  map[string]any{"type": "object"},
		}},
	}, false)
	tools, ok := body["tools"].([]map[string]any)
	if !ok || len(tools) != 1 {
		t.Fatalf("tools = %#v", body["tools"])
	}
	if body["tool_choice"] != "auto" {
		t.Fatalf("tool_choice = %#v", body["tool_choice"])
	}
}

func TestOllamaRequestIncludesTools(t *testing.T) {
	raw, err := json.Marshal(newOllamaChatRequest("qwen2.5", []Message{
		{Role: "assistant", ToolCalls: []ToolCall{{
			ID: "call_1", Type: "function",
			Function: ToolCallFunction{Name: "post_search", Arguments: `{"query":"咖啡"}`},
		}}},
		{Role: "tool", ToolCallID: "call_1", Content: "没有结果"},
	}, ChatOptions{Tools: []Tool{{
		Name: "post_search", Description: "search", Parameters: map[string]any{"type": "object"},
	}}}, false))
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	text := string(raw)
	if !strings.Contains(text, `"tools"`) || !strings.Contains(text, `"post_search"`) {
		t.Fatalf("missing tools: %s", text)
	}
	if !strings.Contains(text, `"arguments":{"query":"咖啡"}`) {
		t.Fatalf("arguments were not sent as an object: %s", text)
	}
	if !strings.Contains(text, `"tool_name":"post_search"`) {
		t.Fatalf("tool result missing tool_name: %s", text)
	}
}

func TestToolArgumentsString(t *testing.T) {
	if got := toolArgumentsString([]byte(`{"query":"咖啡"}`)); !strings.Contains(got, "咖啡") {
		t.Fatalf("arguments = %s", got)
	}
	if got := toolArgumentsString([]byte(`"{\"query\":\"咖啡\"}"`)); !strings.Contains(got, "query") {
		t.Fatalf("decoded arguments = %s", got)
	}
}
