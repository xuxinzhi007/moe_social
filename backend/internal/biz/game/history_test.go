package gamebiz

import (
	"encoding/json"
	"testing"

	"backend/model"
)

func TestBuildHistoryFromLogsNoDuplicateAction(t *testing.T) {
	lines := []NarrativeLine{
		{Type: "action_echo", Content: "看看周围"},
		{Type: "prose", Content: "你停下脚步。"},
	}
	raw, _ := json.Marshal(lines)
	logs := []model.GameTurnLog{{
		UserAction:      "看看周围",
		SystemNarrative: string(raw),
	}}
	history := buildHistoryFromLogs(logs)
	if len(history) != 2 {
		t.Fatalf("expected 2 lines, got %d", len(history))
	}
	if history[0].Type != "action_echo" || history[1].Type != "prose" {
		t.Fatalf("unexpected history: %+v", history)
	}
}
