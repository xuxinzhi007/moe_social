package moebiz

import (
	"context"
	"strconv"
	"strings"
	"time"

	"backend/pkg/moe/toolaudit"

	"gorm.io/gorm"
)

// ToolStatsFilter 工具调用统计筛选。
type ToolStatsFilter struct {
	From     *time.Time
	To       *time.Time
	AgentKey string
	Tool     string
}

// ToolStatsResult 统计结果。
type ToolStatsResult = toolaudit.StatsResult

// ToolCallsFilter 工具调用列表筛选。
type ToolCallsFilter struct {
	From        *time.Time
	To          *time.Time
	AgentKey    string
	Tool        string
	Source      string
	ActorUserID uint
	OkOnly      bool
	FailedOnly  bool
	Page        int
	PageSize    int
}

// ToolCallRow 列表行。
type ToolCallRow struct {
	ID               uint
	Tool             string
	ActorUserID      uint
	AgentKey         string
	Ok               bool
	ErrorMsg         string
	LatencyMs        int
	Source           string
	ArgumentsPreview string
	CreatedAt        time.Time
}

// QueryToolStats 查询工具调用统计。
func QueryToolStats(ctx context.Context, db *gorm.DB, f ToolStatsFilter) (ToolStatsResult, error) {
	_ = ctx
	return toolaudit.QueryStats(db, toolaudit.StatsFilter{
		From:     f.From,
		To:       f.To,
		AgentKey: strings.TrimSpace(f.AgentKey),
		Tool:     strings.TrimSpace(f.Tool),
	})
}

// ListToolCalls 分页列出工具调用。
func ListToolCalls(ctx context.Context, db *gorm.DB, f ToolCallsFilter) ([]ToolCallRow, int64, error) {
	_ = ctx
	rows, total, err := toolaudit.ListCalls(db, toolaudit.ListFilter{
		From:        f.From,
		To:          f.To,
		AgentKey:    strings.TrimSpace(f.AgentKey),
		Tool:        strings.TrimSpace(f.Tool),
		Source:      strings.TrimSpace(f.Source),
		ActorUserID: f.ActorUserID,
		OkOnly:      f.OkOnly,
		FailedOnly:  f.FailedOnly,
		Page:        f.Page,
		PageSize:    f.PageSize,
	})
	if err != nil {
		return nil, 0, err
	}
	out := make([]ToolCallRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, ToolCallRow{
			ID:               row.ID,
			Tool:             row.Tool,
			ActorUserID:      row.ActorUserID,
			AgentKey:         row.AgentKey,
			Ok:               row.Ok,
			ErrorMsg:         row.ErrorMsg,
			LatencyMs:        row.LatencyMs,
			Source:           row.Source,
			ArgumentsPreview: row.ArgumentsPreview,
			CreatedAt:        row.CreatedAt,
		})
	}
	return out, total, nil
}

// ParseActorUserID 解析 actor_user_id。
func ParseActorUserID(raw string) uint {
	v, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 32)
	if err != nil {
		return 0
	}
	return uint(v)
}
