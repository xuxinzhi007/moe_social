package llminference

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestOllamaChatRequestDisablesThink(t *testing.T) {
	raw, err := json.Marshal(ollamaChatRequest{
		Model:    "qwen3:4b",
		Messages: []Message{{Role: "user", Content: "hi"}},
		Stream:   true,
		Think:    false,
	})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if !strings.Contains(string(raw), `"think":false`) {
		t.Fatalf("expected think:false in %s", raw)
	}
}
