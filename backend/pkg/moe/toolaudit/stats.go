package toolaudit

import (
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// StatsFilter 统计筛选条件。
type StatsFilter struct {
	From     *time.Time
	To       *time.Time
	AgentKey string
	Tool     string
}

// ToolStatRow 按工具聚合。
type ToolStatRow struct {
	Tool         string `gorm:"column:tool"`
	TotalCalls   int64  `gorm:"column:total_calls"`
	SuccessCalls int64  `gorm:"column:success_calls"`
	FailedCalls  int64  `gorm:"column:failed_calls"`
}

// DayStatRow 按日聚合。
type DayStatRow struct {
	Date         string `gorm:"column:date"`
	TotalCalls   int64  `gorm:"column:total_calls"`
	SuccessCalls int64  `gorm:"column:success_calls"`
}

// StatsResult 汇总统计结果。
type StatsResult struct {
	TotalCalls   int64
	SuccessCalls int64
	FailedCalls  int64
	ByTool       []ToolStatRow
	ByDay        []DayStatRow
}

// ListFilter 调用明细列表筛选。
type ListFilter struct {
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

func scopedQuery(db *gorm.DB, f StatsFilter) *gorm.DB {
	q := db.Model(&model.MoeToolCall{})
	if f.From != nil {
		q = q.Where("created_at >= ?", *f.From)
	}
	if f.To != nil {
		q = q.Where("created_at < ?", *f.To)
	}
	if f.AgentKey != "" {
		q = q.Where("agent_key = ?", f.AgentKey)
	}
	if f.Tool != "" {
		q = q.Where("tool = ?", f.Tool)
	}
	return q
}

// QueryStats 聚合工具调用统计。
func QueryStats(db *gorm.DB, f StatsFilter) (StatsResult, error) {
	out := StatsResult{}
	if db == nil {
		return out, nil
	}
	base := scopedQuery(db, f)

	var totals struct {
		Total   int64
		Success int64
	}
	if err := base.Select(
		"COUNT(*) as total",
		"SUM(CASE WHEN ok = 1 THEN 1 ELSE 0 END) as success",
	).Scan(&totals).Error; err != nil {
		return out, err
	}
	out.TotalCalls = totals.Total
	out.SuccessCalls = totals.Success
	out.FailedCalls = totals.Total - totals.Success

	var byTool []ToolStatRow
	if err := base.Select(
		"tool",
		"COUNT(*) as total_calls",
		"SUM(CASE WHEN ok = 1 THEN 1 ELSE 0 END) as success_calls",
		"SUM(CASE WHEN ok = 0 THEN 1 ELSE 0 END) as failed_calls",
	).Group("tool").Order("total_calls DESC").Scan(&byTool).Error; err != nil {
		return out, err
	}
	out.ByTool = byTool

	var byDay []DayStatRow
	if err := base.Select(
		"DATE(created_at) as date",
		"COUNT(*) as total_calls",
		"SUM(CASE WHEN ok = 1 THEN 1 ELSE 0 END) as success_calls",
	).Group("DATE(created_at)").Order("date DESC").Limit(14).Scan(&byDay).Error; err != nil {
		return out, err
	}
	out.ByDay = byDay
	return out, nil
}

// ListCalls 分页查询调用明细。
func ListCalls(db *gorm.DB, f ListFilter) ([]model.MoeToolCall, int64, error) {
	if db == nil {
		return nil, 0, nil
	}
	q := db.Model(&model.MoeToolCall{})
	if f.From != nil {
		q = q.Where("created_at >= ?", *f.From)
	}
	if f.To != nil {
		q = q.Where("created_at < ?", *f.To)
	}
	if f.AgentKey != "" {
		q = q.Where("agent_key = ?", f.AgentKey)
	}
	if f.Tool != "" {
		q = q.Where("tool = ?", f.Tool)
	}
	if f.ActorUserID > 0 {
		q = q.Where("actor_user_id = ?", f.ActorUserID)
	}
	if f.Source != "" {
		q = q.Where("source = ?", f.Source)
	}
	if f.OkOnly {
		q = q.Where("ok = ?", true)
	}
	if f.FailedOnly {
		q = q.Where("ok = ?", false)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	page := f.Page
	if page < 1 {
		page = 1
	}
	size := f.PageSize
	if size < 1 {
		size = 20
	}
	if size > 100 {
		size = 100
	}
	offset := (page - 1) * size
	var rows []model.MoeToolCall
	err := q.Order("created_at DESC").Offset(offset).Limit(size).Find(&rows).Error
	return rows, total, err
}
