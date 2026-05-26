package runtime

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/core"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"

	"gorm.io/gorm"
)

// RunOnceResult 单次 Bot 回合结果。
type RunOnceResult struct {
	AgentKey string `json:"agent_key"`
	OK       bool   `json:"ok"`
	Detail   string `json:"detail"`
	PostID   string `json:"post_id,omitempty"`
}

// RunOnce 执行一次 Bot 回合：LLM 生成正文 + post_create 发帖。
func RunOnce(ctx context.Context, deps Deps, agentKey string) (RunOnceResult, error) {
	agentKey = strings.TrimSpace(agentKey)
	if agentKey == "" {
		return RunOnceResult{}, fmt.Errorf("agent_key 为空")
	}
	if deps.DB == nil {
		return RunOnceResult{}, fmt.Errorf("数据库未就绪")
	}

	var rt model.MoeAgentRuntime
	if err := deps.DB.Where("agent_key = ? AND enabled = ?", agentKey, true).First(&rt).Error; err != nil {
		return RunOnceResult{}, fmt.Errorf("未找到启用的 runtime: %s", agentKey)
	}

	tier := core.ParseTier(rt.CapabilityTier)
	exec := tools.NewExecutor(tools.Deps{DB: deps.DB, RPC: deps.RPC})

	gen, genErr := generatePostContent(ctx, deps, rt)
	if genErr != nil {
		return RunOnceResult{
			AgentKey: rt.AgentKey,
			OK:       false,
			Detail:   genErr.Error(),
		}, nil
	}

	argsJSON, _ := json.Marshal(map[string]string{
		"content":  gen.Content,
		"mood_tag": gen.MoodTag,
	})
	execReq := core.ExecuteRequest{
		Tool:          "post_create",
		ArgumentsJSON: string(argsJSON),
		BotUserID:     rt.BotUserID,
		ActorUserID:   rt.BotUserID,
		AgentKey:      rt.AgentKey,
		Tier:          tier,
	}
	start := time.Now()
	toolRes := exec.Execute(ctx, execReq)
	toolaudit.Record(deps.DB, toolaudit.RecordInput{
		Tool:          execReq.Tool,
		ArgumentsJSON: execReq.ArgumentsJSON,
		ActorUserID:   execReq.ActorUserID,
		BotUserID:     execReq.BotUserID,
		AgentKey:      execReq.AgentKey,
		Ok:            toolRes.OK,
		ErrorMsg:      toolRes.Error,
		LatencyMs:     int(time.Since(start).Milliseconds()),
		Source:        "runtime",
	})

	out := RunOnceResult{
		AgentKey: rt.AgentKey,
		OK:       toolRes.OK,
		Detail:   toolRes.Result,
	}
	if !toolRes.OK {
		out.Detail = toolRes.Error
		return out, nil
	}
	out.Detail = fmt.Sprintf("ai_post(%s): %s", gen.Source, toolRes.Result)
	var parsed map[string]any
	if json.Unmarshal([]byte(toolRes.Result), &parsed) == nil {
		if id, ok := parsed["post_id"].(string); ok {
			out.PostID = id
			score := novelStyleScore(gen.Content)
			_ = brain.RecordEpisode(ctx, brain.Deps{DB: deps.DB, RPC: deps.RPC}, brain.RecordInput{
				AgentKey:   rt.AgentKey,
				BotUserID:  rt.BotUserID,
				PostID:     id,
				Content:    gen.Content,
				MoodTag:    gen.MoodTag,
				StyleScore: score,
				Source:     gen.Source,
			})
		}
	}
	now := time.Now()
	_ = deps.DB.Model(&rt).Update("last_run_at", now).Error
	return out, nil
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
