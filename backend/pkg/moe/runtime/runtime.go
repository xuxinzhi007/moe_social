package runtime

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/moe/core"

	"gorm.io/gorm"
)

// RunOnceResult 单次 Bot 回合结果。
type RunOnceResult struct {
	AgentKey string `json:"agent_key"`
	OK       bool   `json:"ok"`
	Detail   string `json:"detail"`
	PostID   string `json:"post_id,omitempty"`
}

// ListRuntimes 列出全部运行时配置。
func ListRuntimes(db *gorm.DB) ([]model.MoeAgentRuntime, error) {
	var rows []model.MoeAgentRuntime
	err := db.Order("agent_key asc").Find(&rows).Error
	return rows, err
}

// UpsertRuntime 创建或更新运行时。
func UpsertRuntime(db *gorm.DB, rt *model.MoeAgentRuntime) error {
	if rt == nil || strings.TrimSpace(rt.AgentKey) == "" {
		return fmt.Errorf("agent_key 必填")
	}
	rt.AgentKey = strings.TrimSpace(rt.AgentKey)
	rt.CapabilityTier = string(core.ParseTier(rt.CapabilityTier))
	rt.PostScheduleMode = NormalizeScheduleMode(rt.PostScheduleMode)
	mode, cronExpr, next, schedErr := ApplyScheduleFields(rt.PostScheduleMode, rt.ScheduleCron, time.Now())
	if schedErr != nil {
		return schedErr
	}
	rt.PostScheduleMode = mode
	rt.ScheduleCron = cronExpr
	rt.NextRunAt = next
	now := time.Now()
	var existing model.MoeAgentRuntime
	err := db.Where("agent_key = ?", rt.AgentKey).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		rt.CreatedAt = now
		rt.UpdatedAt = now
		return db.Create(rt).Error
	}
	if err != nil {
		return err
	}
	rt.ID = existing.ID
	rt.CreatedAt = existing.CreatedAt
	rt.UpdatedAt = now
	return db.Save(rt).Error
}
