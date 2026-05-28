package toolaudit

import (
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// InvokedTool 时间窗内一次工具调用摘要。
type InvokedTool struct {
	Tool      string
	Ok        bool
	LatencyMs int
	CreatedAt time.Time
}

// ListInvokedSince 列出 agent 自 since 起的工具调用（升序）。
func ListInvokedSince(db *gorm.DB, agentKey string, since time.Time, limit int) ([]InvokedTool, error) {
	if db == nil || agentKey == "" {
		return nil, nil
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	var rows []model.MoeToolCall
	q := db.Where("agent_key = ?", agentKey)
	if !since.IsZero() {
		q = q.Where("created_at >= ?", since)
	}
	if err := q.Order("created_at asc").Limit(limit).Find(&rows).Error; err != nil {
		return nil, err
	}
	out := make([]InvokedTool, 0, len(rows))
	for _, r := range rows {
		out = append(out, InvokedTool{
			Tool: r.Tool, Ok: r.Ok, LatencyMs: r.LatencyMs, CreatedAt: r.CreatedAt,
		})
	}
	return out, nil
}
