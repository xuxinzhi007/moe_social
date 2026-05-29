package bootstrap

import (
	"context"
	"time"

	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/runtime"

	"backend/internal/platform/moelog"

	"gorm.io/gorm"
)

func runDreamSchedulerLoop(parent context.Context, db *gorm.DB, deps brain.RpgDeps, opts brain.DreamSchedulerOpts) {
	if !opts.Enabled || db == nil {
		moelog.Info("moe dream scheduler disabled")
		return
	}
	tick := opts.TickInterval
	if tick <= 0 {
		tick = 5 * time.Minute
	}
	go func() {
		time.Sleep(5 * time.Second)
		ticker := time.NewTicker(tick)
		defer ticker.Stop()
		for {
			select {
			case <-parent.Done():
				moelog.Info("moe dream scheduler stopped")
				return
			case <-ticker.C:
				runDueDreams(parent, deps, db)
			}
		}
	}()
	moelog.Infof("moe dream scheduler started tick=%s", tick)
}

func runDueDreams(ctx context.Context, deps brain.RpgDeps, db *gorm.DB) {
	var rows []model.MoeAgentRuntime
	if err := db.Where("enabled = ?", true).Find(&rows).Error; err != nil {
		moelog.Errorf("dream scheduler list: %v", err)
		return
	}
	now := time.Now()
	for i := range rows {
		rt := rows[i]
		cfg := brain.LoadRpgConfigFromDB(db, rt.AgentKey)
		if !cfg.DreamEnabled {
			continue
		}
		cronExpr := cfg.DreamCron
		if cronExpr == "" {
			cronExpr = brain.DefaultDreamCron()
		}
		if !brain.DreamDue(cfg.NextDreamAt, now) {
			continue
		}
		if brain.IsDreaming(rt.AgentKey) || runtime.LiveRuns.IsRunning(rt.AgentKey) {
			continue
		}
		moelog.Infof("dream scheduler run agent=%s", rt.AgentKey)
		_, err := brain.RunDream(ctx, deps, rt.AgentKey, false)
		if err != nil {
			moelog.Errorf("dream scheduler %s: %v", rt.AgentKey, err)
		}
		next, nerr := brain.NextDreamCronRun(cronExpr, now)
		if nerr != nil {
			continue
		}
		cfg.NextDreamAt = next.Format("2006-01-02 15:04:05")
		_ = brain.SaveRpgConfig(db, rt.AgentKey, cfg)
	}
}
