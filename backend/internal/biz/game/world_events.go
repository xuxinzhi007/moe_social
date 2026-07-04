package gamebiz

import (
	"context"
	"fmt"
	"strings"

	"backend/model"
)

func formatWorldEventLine(scene, eventType, summary string) string {
	summary = strings.TrimSpace(summary)
	scene = strings.TrimSpace(scene)
	prefix := "⚡ "
	switch strings.TrimSpace(eventType) {
	case "discovery":
		prefix = "🔍 "
	case "weather":
		prefix = "🌫 "
	case "npc":
		prefix = "👤 "
	case "ambient":
		prefix = "🌍 "
	}
	if scene != "" {
		return prefix + scene + "：" + summary
	}
	return prefix + summary
}

func persistWorldEvent(ctx context.Context, st Store, sessionID uint, scene, eventType, summary string) error {
	if st == nil || sessionID == 0 {
		return fmt.Errorf("invalid world event target")
	}
	summary = strings.TrimSpace(summary)
	if summary == "" {
		return fmt.Errorf("summary required")
	}
	if scene == "" {
		scene = "未知地点"
	}
	if eventType == "" {
		eventType = "ambient"
	}
	if hasDuplicateWorldEvent(ctx, st, sessionID, summary) {
		return nil
	}
	return st.CreateWorldEvent(ctx, &model.GameWorldEvent{
		SessionID:   sessionID,
		SceneName:   scene,
		EventType:   eventType,
		Summary:     summary,
		IsDelivered: false,
	})
}

func hasDuplicateWorldEvent(ctx context.Context, st Store, sessionID uint, summary string) bool {
	rows, err := st.ListRecentWorldEvents(ctx, sessionID, 6)
	if err != nil {
		return false
	}
	for _, row := range rows {
		if strings.TrimSpace(row.Summary) == summary {
			return true
		}
	}
	return false
}

func loadUndeliveredEventLines(ctx context.Context, st Store, sessionID uint) ([]NarrativeLine, error) {
	if st == nil || sessionID == 0 {
		return nil, nil
	}
	rows, err := st.ListUndeliveredWorldEvents(ctx, sessionID, 8)
	if err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return nil, nil
	}
	lines := make([]NarrativeLine, 0, len(rows))
	ids := make([]uint, 0, len(rows))
	for _, row := range rows {
		lines = append(lines, NarrativeLine{
			Type:    "event",
			Content: formatWorldEventLine(row.SceneName, row.EventType, row.Summary),
		})
		ids = append(ids, row.ID)
	}
	if err := st.MarkWorldEventsDelivered(ctx, ids); err != nil {
		return lines, err
	}
	return lines, nil
}

func listRecentEventSummaries(ctx context.Context, st Store, sessionID uint, limit int) []string {
	if st == nil {
		return nil
	}
	rows, err := st.ListRecentWorldEvents(ctx, sessionID, limit)
	if err != nil {
		return nil
	}
	out := make([]string, 0, len(rows))
	for _, row := range rows {
		out = append(out, formatWorldEventLine(row.SceneName, row.EventType, row.Summary))
	}
	return out
}
