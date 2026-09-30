package llminference

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestOllamaChatRequestDisablesThink(t *testing.T) {
	raw, err := json.Marshal(newOllamaChatRequest("qwen3:4b", []Message{{Role: "user", Content: "hi"}}, ChatOptions{}, true))
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if !strings.Contains(string(raw), `"think":false`) {
		t.Fatalf("expected think:false in %s", raw)
	}
}
