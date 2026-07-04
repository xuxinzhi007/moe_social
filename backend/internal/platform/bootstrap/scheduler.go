package bootstrap

import (
	"context"

	"backend/internal/adapter/moeconfig"
	moebiz "backend/internal/biz/moe"
	moedata "backend/internal/data/moe"
	"backend/internal/platform/moewiring"
	platformsvc "backend/internal/platform/svc"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/flowexec"
	"backend/pkg/moe/runtime"
	"backend/utils"

	"gorm.io/gorm"
)

// StartDreamScheduler starts the Memory RPG dream scheduler.
func StartDreamScheduler(parent context.Context, svc *platformsvc.ServiceContext) {
	if svc == nil {
		return
	}
	appPort := moewiring.NewAppAdapter(svc.Domains.Community.PostApp, svc.Domains.AI.LLMApp)
	if appPort == nil {
		return
	}
	db := utils.GetDB()
	if db == nil {
		return
	}
	inf := moeconfig.InferenceFromViper()
	deps := brain.RefineDeps{DB: db, RPC: appPort, Inference: inf}
	rpgDeps := brain.RpgDeps{DB: db, RPC: appPort, Inference: deps}
	runDreamSchedulerLoop(parent, db, rpgDeps, brain.LoadDreamSchedulerOptsFromViper())
}

// StartMoeBotScheduler starts bot post scheduling in the HTTP process.
func StartMoeBotScheduler(parent context.Context, svc *platformsvc.ServiceContext) {
	if svc == nil {
		return
	}
	appPort := moewiring.NewAppAdapter(svc.Domains.Community.PostApp, svc.Domains.AI.LLMApp)
	if appPort == nil {
		return
	}
	db := utils.GetDB()
	if db == nil {
		return
	}
	sp := appPort
	inf := moeconfig.InferenceFromViper()
	deps := runtime.Deps{
		DB:        db,
		RPC:       sp,
		Inference: inf,
		ResolvePostingPlan: func(ctx context.Context, gdb *gorm.DB, agentKey string) (flowexec.Plan, error) {
			return moebiz.ResolvePostingPlan(ctx, moedata.NewStore(gdb), agentKey)
		},
	}
	sched := runtime.LoadSchedulerOptsFromViper()
	runtime.StartScheduler(parent, deps, sched.SchedulerOpts, sched.Smart)
}
