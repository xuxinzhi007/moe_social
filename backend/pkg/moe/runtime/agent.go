package runtime

import (
	"context"
	"fmt"
	"strings"
	"time"

	"backend/pkg/moe/brain"
	"backend/pkg/moe/flowexec"
)

// RunTrigger 触发来源（与 cron / 试跑同级）。
type RunTrigger string

const (
	TriggerManual    RunTrigger = "manual"
	TriggerCron      RunTrigger = "cron"
	TriggerSmart     RunTrigger = "smart"
	TriggerAdminTest RunTrigger = "admin_test"
)

// RunAgent 按编排计划执行 Bot 发帖回合（E1）。
func RunAgent(ctx context.Context, deps Deps, agentKey string, trigger RunTrigger, plan flowexec.Plan) (RunOnceResult, error) {
	agentKey = strings.TrimSpace(agentKey)
	_ = trigger
	rec := NewStepRecorder()
	if agentKey == "" {
		return RunOnceResult{}, fmt.Errorf("agent_key 为空")
	}
	if deps.DB == nil {
		return RunOnceResult{}, fmt.Errorf("数据库未就绪")
	}
	if len(plan.Nodes) == 0 {
		plan = resolvePostingPlan(ctx, deps, agentKey)
	}

	saveLog := func(ok bool, detail, postID string, genAttempts []GenAttemptRecord, postQuality int) {
		metrics := SampleHostMetrics(ctx, deps.Inference)
		bundle := rec.Bundle(metrics)
		if len(genAttempts) > 0 {
			bundle.GenerateAttempts = genAttempts
		}
		delta, feedback := ComputeStabilityDelta(ok, genAttempts, postQuality)
		if score, err := brain.ApplyStabilityDelta(deps.DB, agentKey, delta); err == nil {
			bundle.StabilityScore = score
			bundle.StabilityDelta = delta
			bundle.RunFeedback = feedback
		}
		_ = SaveAgentRunLog(deps.DB, agentKey, ok, detail, postID, bundle)
	}

	out, st, err := executeFlowPlan(ctx, deps, agentKey, plan, rec)
	if err != nil {
		if out.AgentKey != "" {
			saveLog(false, out.Detail, "", st.genAttempts, 0)
			return out, nil
		}
		saveLog(false, err.Error(), "", nil, 0)
		return RunOnceResult{}, err
	}
	postQuality := 0
	if out.OK && st.gen.Content != "" {
		forbidden := brain.ParseTagList(st.rt.ForbiddenTags)
		postQuality = brain.ComputeQualityScore(st.gen.Content, st.gen.MoodTag, novelStyleScore(st.gen.Content), forbidden)
	}
	_ = deps.DB.Model(&st.rt).Update("last_run_at", time.Now()).Error
	saveLog(out.OK, out.Detail, out.PostID, st.genAttempts, postQuality)
	return out, nil
}

// RunAgentForAgent 加载该 Bot 画布编排并执行。
func RunAgentForAgent(ctx context.Context, deps Deps, agentKey string, trigger RunTrigger) (RunOnceResult, error) {
	return RunAgent(ctx, deps, agentKey, trigger, resolvePostingPlan(ctx, deps, agentKey))
}

// RunOnce 兼容入口：按画布编排执行（无画布时用默认图）。
func RunOnce(ctx context.Context, deps Deps, agentKey string) (RunOnceResult, error) {
	return RunAgentForAgent(ctx, deps, agentKey, TriggerManual)
}

func resolvePostingPlan(ctx context.Context, deps Deps, agentKey string) flowexec.Plan {
	if deps.ResolvePostingPlan != nil && deps.DB != nil {
		plan, err := deps.ResolvePostingPlan(ctx, deps.DB, agentKey)
		if err == nil && len(plan.Nodes) > 0 {
			return plan
		}
	}
	return flowexec.DefaultPostingPlan()
}
