package bootstrap

import (
	"context"

	"backend/internal/adapter/moeconfig"
	moebiz "backend/internal/biz/moe"
	moedata "backend/internal/data/moe"
	"backend/internal/platform/moewiring"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/flowexec"
	"backend/pkg/moe/runtime"
	"backend/utils"

	"gorm.io/gorm"
)

// StartDreamScheduler starts the Memory RPG dream scheduler.
func StartDreamScheduler(parent context.Context, deps Deps) {
	appPort := moewiring.NewAppAdapter(deps.PostApp, deps.LLMApp)
	if appPort == nil {
		return
	}
	db := utils.GetDB()
	if db == nil {
		return
	}
	inf := moeconfig.InferenceFromViper()
	refineDeps := brain.RefineDeps{DB: db, RPC: appPort, Inference: inf}
	rpgDeps := brain.RpgDeps{DB: db, RPC: appPort, Inference: refineDeps}
	runDreamSchedulerLoop(parent, db, rpgDeps, brain.LoadDreamSchedulerOptsFromViper())
}

// StartMoeBotScheduler starts bot post scheduling in the HTTP process.
func StartMoeBotScheduler(parent context.Context, deps Deps) {
	appPort := moewiring.NewAppAdapter(deps.PostApp, deps.LLMApp)
	if appPort == nil {
		return
	}
	db := utils.GetDB()
	if db == nil {
		return
	}
	inf := moeconfig.InferenceFromViper()
	runtimeDeps := runtime.Deps{
		DB:        db,
		RPC:       appPort,
		Inference: inf,
		ResolvePostingPlan: func(ctx context.Context, gdb *gorm.DB, agentKey string) (flowexec.Plan, error) {
			return moebiz.ResolvePostingPlan(ctx, moedata.NewStore(gdb), agentKey)
		},
	}
	sched := runtime.LoadSchedulerOptsFromViper()
	runtime.StartScheduler(parent, runtimeDeps, sched.SchedulerOpts, sched.Smart)
}
