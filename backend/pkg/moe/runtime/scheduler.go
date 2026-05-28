package runtime

import (
	"context"
	"sync"
	"time"

	"backend/model"

	"backend/internal/platform/moelog"
	"gorm.io/gorm"
)

// SchedulerOpts 后台 Bot 定时发帖。
type SchedulerOpts struct {
	Enabled      bool
	TickInterval time.Duration
}

var (
	schedulerMu     sync.Mutex
	schedulerCancel context.CancelFunc
)

// StartScheduler 在 RPC 进程内启动定时扫描（cron + smart）。
func StartScheduler(parent context.Context, deps Deps, opts SchedulerOpts, smart SmartOpts) {
	if !opts.Enabled {
		moelog.Info("moe bot scheduler disabled")
		return
	}
	if deps.DB == nil {
		moelog.Error("moe bot scheduler: db nil")
		return
	}
	tick := opts.TickInterval
	if tick <= 0 {
		tick = time.Minute
	}

	schedulerMu.Lock()
	if schedulerCancel != nil {
		schedulerCancel()
	}
	ctx, cancel := context.WithCancel(parent)
	schedulerCancel = cancel
	schedulerMu.Unlock()

	moelog.Infof("moe bot scheduler started tick=%s", tick)

	go func() {
		// 启动后稍等 DB 就绪
		time.Sleep(3 * time.Second)
		ticker := time.NewTicker(tick)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				moelog.Info("moe bot scheduler stopped")
				return
			case <-ticker.C:
				runDueScheduled(ctx, deps, smart)
			}
		}
	}()
}

func runDueScheduled(ctx context.Context, deps Deps, smart SmartOpts) {
	now := time.Now()
	var rows []model.MoeAgentRuntime
	err := deps.DB.Where(
		"enabled = ? AND post_schedule_mode = ? AND schedule_cron <> '' AND (next_run_at IS NULL OR next_run_at <= ?)",
		true, ScheduleCron, now,
	).Find(&rows).Error
	if err != nil {
		moelog.Errorf("moe scheduler list: %v", err)
		return
	}
	for i := range rows {
		rt := rows[i]
		moelog.Infof("moe scheduler run agent=%s bot_user=%d", rt.AgentKey, rt.BotUserID)
		result, runErr := RunAgentForAgent(ctx, deps, rt.AgentKey, TriggerCron)
		if runErr != nil {
			moelog.Errorf("moe scheduler run-once %s: %v", rt.AgentKey, runErr)
			continue
		}
		if !result.OK {
			moelog.Errorf("moe scheduler run-once %s failed: %s", rt.AgentKey, result.Detail)
		} else {
			moelog.Infof("moe scheduler posted agent=%s post_id=%s", rt.AgentKey, result.PostID)
		}
		next, nerr := NextCronRun(rt.ScheduleCron, now)
		if nerr != nil {
			moelog.Errorf("moe scheduler next run %s: %v", rt.AgentKey, nerr)
			continue
		}
		_ = deps.DB.Model(&model.MoeAgentRuntime{}).Where("id = ?", rt.ID).
			Update("next_run_at", next).Error
	}

	runDueSmart(ctx, deps, smart, now)
}

func runDueSmart(ctx context.Context, deps Deps, smart SmartOpts, now time.Time) {
	var rows []model.MoeAgentRuntime
	err := deps.DB.Where(
		"enabled = ? AND post_schedule_mode = ? AND (next_run_at IS NULL OR next_run_at <= ?)",
		true, ScheduleSmart, now,
	).Find(&rows).Error
	if err != nil {
		moelog.Errorf("moe smart scheduler list: %v", err)
		return
	}
	for i := range rows {
		rt := rows[i]
		should, reason, evalErr := evaluateSmartPost(ctx, deps, rt, smart)
		if evalErr != nil {
			moelog.Errorf("moe smart evaluate %s: %v", rt.AgentKey, evalErr)
			retry := smartRetryAt(now, smart)
			_ = deps.DB.Model(&model.MoeAgentRuntime{}).Where("id = ?", rt.ID).
				Update("next_run_at", retry).Error
			continue
		}
		if !should {
			moelog.Infof("moe smart skip agent=%s reason=%s", rt.AgentKey, reason)
			retry := smartRetryAt(now, smart)
			if rt.ScheduleCron != "" {
				if next, nerr := NextCronRun(rt.ScheduleCron, now); nerr == nil {
					if next.After(retry) {
						retry = next
					}
				}
			}
			_ = deps.DB.Model(&model.MoeAgentRuntime{}).Where("id = ?", rt.ID).
				Update("next_run_at", retry).Error
			continue
		}
		moelog.Infof("moe smart post agent=%s reason=%s", rt.AgentKey, reason)
		result, runErr := RunAgentForAgent(ctx, deps, rt.AgentKey, TriggerCron)
		if runErr != nil {
			moelog.Errorf("moe smart run-once %s: %v", rt.AgentKey, runErr)
			continue
		}
		if !result.OK {
			moelog.Errorf("moe smart run-once %s failed: %s", rt.AgentKey, result.Detail)
		} else {
			moelog.Infof("moe smart posted agent=%s post_id=%s", rt.AgentKey, result.PostID)
		}
		retry := smartRetryAt(now, smart)
		if rt.ScheduleCron != "" {
			if next, nerr := NextCronRun(rt.ScheduleCron, now); nerr == nil && next.After(retry) {
				retry = next
			}
		}
		_ = deps.DB.Model(&model.MoeAgentRuntime{}).Where("id = ?", rt.ID).
			Update("next_run_at", retry).Error
	}
}

// RefreshNextRunAt 保存配置后刷新下次执行时间。
func RefreshNextRunAt(db *gorm.DB, rt *model.MoeAgentRuntime) error {
	if db == nil || rt == nil {
		return nil
	}
	mode, cronExpr, next, err := ApplyScheduleFields(rt.PostScheduleMode, rt.ScheduleCron, time.Now())
	if err != nil {
		return err
	}
	rt.PostScheduleMode = mode
	rt.ScheduleCron = cronExpr
	rt.NextRunAt = next
	return db.Model(rt).Updates(map[string]any{
		"post_schedule_mode": mode,
		"schedule_cron":      cronExpr,
		"next_run_at":        next,
	}).Error
}
