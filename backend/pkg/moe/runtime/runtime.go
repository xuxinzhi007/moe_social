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
	rec := NewStepRecorder()
	if agentKey == "" {
		return RunOnceResult{}, fmt.Errorf("agent_key 为空")
	}
	if deps.DB == nil {
		return RunOnceResult{}, fmt.Errorf("数据库未就绪")
	}

	saveLog := func(ok bool, detail, postID string, genAttempts []GenAttemptRecord) {
		metrics := SampleHostMetrics(ctx, deps.Inference)
		bundle := rec.Bundle(metrics)
		if len(genAttempts) > 0 {
			bundle.GenerateAttempts = genAttempts
		}
		_ = SaveAgentRunLog(deps.DB, agentKey, ok, detail, postID, bundle)
	}

	stepStart := time.Now()
	var rt model.MoeAgentRuntime
	if err := deps.DB.Where("agent_key = ? AND enabled = ?", agentKey, true).First(&rt).Error; err != nil {
		rec.Add("load_runtime", "加载 Bot 配置", "fail", err.Error(), time.Since(stepStart))
		saveLog(false, err.Error(), "", nil)
		return RunOnceResult{}, fmt.Errorf("未找到启用的 runtime: %s", agentKey)
	}
	rec.Add("load_runtime", "加载 Bot 配置", "ok", rt.DisplayName, time.Since(stepStart))

	tier := core.ParseTier(rt.CapabilityTier)
	exec := tools.NewExecutor(tools.Deps{DB: deps.DB, RPC: deps.RPC})

	stepStart = time.Now()
	rec.Add("gather_memory", "检索记忆与社区脉搏", "ok", "组装发帖 prompt", time.Since(stepStart))

	stepStart = time.Now()
	gen, genAttempts, genErr := generatePostContent(ctx, deps, rt)
	genDur := time.Since(stepStart)
	if genErr != nil {
		runDetail := FormatRunDetailFromGen(genAttempts, false, "", genErr)
		rec.Add("generate", "LLM 生成正文", "fail", FormatGenStepDetail(genAttempts, false, ""), genDur)
		saveLog(false, runDetail, "", genAttempts)
		return RunOnceResult{
			AgentKey: rt.AgentKey,
			OK:       false,
			Detail:   runDetail,
		}, nil
	}
	genStepDetail := FormatGenStepDetail(genAttempts, true, gen.Source)
	rec.Add("generate", "LLM 生成正文", "ok", genStepDetail, genDur)

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
	stepStart = time.Now()
	toolRes := exec.Execute(ctx, execReq)
	postDur := time.Since(stepStart)
	toolaudit.Record(deps.DB, toolaudit.RecordInput{
		Tool:          execReq.Tool,
		ArgumentsJSON: execReq.ArgumentsJSON,
		ActorUserID:   execReq.ActorUserID,
		BotUserID:     execReq.BotUserID,
		AgentKey:      execReq.AgentKey,
		Ok:            toolRes.OK,
		ErrorMsg:      toolRes.Error,
		LatencyMs:     int(postDur.Milliseconds()),
		Source:        "runtime",
	})

	out := RunOnceResult{
		AgentKey: rt.AgentKey,
		OK:       toolRes.OK,
		Detail:   toolRes.Result,
	}
	if !toolRes.OK {
		out.Detail = toolRes.Error
		rec.Add("post_create", "发布动态", "fail", toolRes.Error, postDur)
		runDetail := FormatRunDetailFromGen(genAttempts, false, "", fmt.Errorf("%s", toolRes.Error))
		saveLog(false, runDetail, "", genAttempts)
		out.Detail = runDetail
		return out, nil
	}
	rec.Add("post_create", "发布动态", "ok", fmt.Sprintf("%dms", postDur.Milliseconds()), postDur)
	out.Detail = FormatRunDetailFromGen(genAttempts, true, gen.Source, nil)
	if out.Detail == "" {
		out.Detail = fmt.Sprintf("ai_post(%s): %s", gen.Source, toolRes.Result)
	}
	var parsed map[string]any
	if json.Unmarshal([]byte(toolRes.Result), &parsed) == nil {
		if id, ok := parsed["post_id"].(string); ok {
			out.PostID = id
			score := novelStyleScore(gen.Content)
			epStart := time.Now()
			_ = brain.RecordEpisode(ctx, brain.Deps{DB: deps.DB, RPC: deps.RPC}, brain.RecordInput{
				AgentKey:   rt.AgentKey,
				BotUserID:  rt.BotUserID,
				PostID:     id,
				Content:    gen.Content,
				MoodTag:    gen.MoodTag,
				StyleScore: score,
				Source:     gen.Source,
			})
			rec.Add("record_episode", "写入自传", "ok", id, time.Since(epStart))
		}
	}
	now := time.Now()
	_ = deps.DB.Model(&rt).Update("last_run_at", now).Error
	saveLog(out.OK, out.Detail, out.PostID, genAttempts)
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
