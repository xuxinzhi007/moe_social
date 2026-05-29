package bootstrap

import (
	"context"

	"backend/internal/adapter/moeconfig"
	"backend/internal/adapter/rpcsuper"
	moebiz "backend/internal/biz/moe"
	moedata "backend/internal/data/moe"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/flowexec"
	"backend/pkg/moe/port"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/tools"
	"backend/rpc/internal/svc"

	"gorm.io/gorm"
)

// AttachMoeAdminHooks 向 MoeAdmin 注入 RPC 侧依赖（避免 svc ↔ bootstrap 循环 import）。
func AttachMoeAdminHooks(svcCtx *svc.ServiceContext) {
	if svcCtx == nil || svcCtx.MoeAdmin == nil {
		return
	}
	bridge := newAppBridge(svcCtx)
	svcCtx.MoeAdmin.AttachRuntimeDeps(func(ctx context.Context) runtime.Deps {
		return moeRuntimeDeps(ctx, svcCtx)
	})
	svcCtx.MoeAdmin.AttachMoeToolPort(func(ctx context.Context) port.MoeToolPort {
		return rpcsuper.NewMoeToolPort(ctx, bridge)
	})
	svcCtx.MoeAdmin.AttachBrainDeps(func(ctx context.Context) brain.Deps {
		return moeBrainDeps(ctx, svcCtx)
	})
	svcCtx.MoeAdmin.AttachBrainRefineDeps(func(ctx context.Context) brain.RefineDeps {
		return moeBrainRefineDeps(ctx, svcCtx)
	})
	svcCtx.MoeAdmin.AttachToolsDeps(func(ctx context.Context) tools.Deps {
		return moeToolsDeps(ctx, svcCtx)
	})
}

func moeToolBridge(ctx context.Context, svc *svc.ServiceContext) rpcsuper.Bridge {
	return newAppBridge(svc)
}

func moeRuntimeDeps(ctx context.Context, svc *svc.ServiceContext) runtime.Deps {
	return runtime.Deps{
		DB:        svc.DB,
		RPC:       rpcsuper.NewMoeToolPort(ctx, moeToolBridge(ctx, svc)),
		Inference: moeconfig.InferenceFromViper(),
		ResolvePostingPlan: func(ctx context.Context, db *gorm.DB, agentKey string) (flowexec.Plan, error) {
			return moebiz.ResolvePostingPlan(ctx, moedata.NewStore(db), agentKey)
		},
	}
}

func moeToolsDeps(ctx context.Context, svc *svc.ServiceContext) tools.Deps {
	return tools.Deps{
		DB:        svc.DB,
		RPC:       rpcsuper.NewMoeToolPort(ctx, moeToolBridge(ctx, svc)),
		Inference: moeconfig.InferenceFromViper(),
	}
}

func moeBrainDeps(ctx context.Context, svc *svc.ServiceContext) brain.Deps {
	return brain.Deps{
		DB:  svc.DB,
		RPC: rpcsuper.NewMoeToolPort(ctx, moeToolBridge(ctx, svc)),
	}
}

func moeBrainRefineDeps(ctx context.Context, svc *svc.ServiceContext) brain.RefineDeps {
	return brain.RefineDeps{
		DB:        svc.DB,
		RPC:       rpcsuper.NewMoeToolPort(ctx, moeToolBridge(ctx, svc)),
		Inference: moeconfig.InferenceFromViper(),
	}
}

// StartBotScheduler 在 RPC 进程启动 Bot 定时发帖。
func StartBotScheduler(parent context.Context, svc *svc.ServiceContext) {
	sched := runtime.LoadSchedulerOptsFromViper()
	runtime.StartScheduler(parent, moeRuntimeDeps(parent, svc), sched.SchedulerOpts, sched.Smart)
}
