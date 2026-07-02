package gamebiz

import (
	"context"
	"encoding/json"

	"backend/model"
	"strings"
)

func buildHistoryFromLogs(logs []model.GameTurnLog) []NarrativeLine {
	out := make([]NarrativeLine, 0, len(logs)*2)
	for _, log := range logs {
		if log.SystemNarrative == "" {
			if action := strings.TrimSpace(log.UserAction); action != "" {
				out = append(out, NarrativeLine{Type: "action_echo", Content: action})
			}
			continue
		}
		var lines []NarrativeLine
		if err := json.Unmarshal([]byte(log.SystemNarrative), &lines); err != nil {
			if action := strings.TrimSpace(log.UserAction); action != "" {
				out = append(out, NarrativeLine{Type: "action_echo", Content: action})
			}
			continue
		}
		out = append(out, lines...)
	}
	return out
}

func loadSessionHistory(ctx context.Context, st Store, sessionID uint, limit int) ([]NarrativeLine, error) {
	logs, err := st.ListTurnLogs(ctx, sessionID, limit)
	if err != nil {
		return nil, err
	}
	return buildHistoryFromLogs(logs), nil
}
