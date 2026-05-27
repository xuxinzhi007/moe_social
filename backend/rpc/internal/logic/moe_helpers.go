package logic

import (
	"context"

	"backend/internal/adapter/moeconfig"
	"backend/internal/adapter/rpcsuper"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/tools"
	"backend/rpc/internal/svc"
)

func moeSuperPort(ctx context.Context, svc *svc.ServiceContext) rpcsuper.Bridge {
	return newSuperBridge(svc)
}

func moeRuntimeDeps(ctx context.Context, svc *svc.ServiceContext) runtime.Deps {
	return runtime.Deps{
		DB:        svc.DB,
		RPC:       rpcsuper.NewSuperPort(ctx, moeSuperPort(ctx, svc)),
		Inference: moeconfig.InferenceFromViper(),
	}
}

func moeToolsDeps(ctx context.Context, svc *svc.ServiceContext) tools.Deps {
	return tools.Deps{
		DB:        svc.DB,
		RPC:       rpcsuper.NewSuperPort(ctx, moeSuperPort(ctx, svc)),
		Inference: moeconfig.InferenceFromViper(),
	}
}

func moeBrainDeps(ctx context.Context, svc *svc.ServiceContext) brain.Deps {
	return brain.Deps{
		DB:  svc.DB,
		RPC: rpcsuper.NewSuperPort(ctx, moeSuperPort(ctx, svc)),
	}
}

func moeBrainRefineDeps(ctx context.Context, svc *svc.ServiceContext) brain.RefineDeps {
	return brain.RefineDeps{
		DB:        svc.DB,
		RPC:       rpcsuper.NewSuperPort(ctx, moeSuperPort(ctx, svc)),
		Inference: moeconfig.InferenceFromViper(),
	}
}

// StartBotScheduler 在 RPC 进程启动 Bot 定时发帖。
func StartBotScheduler(parent context.Context, svc *svc.ServiceContext) {
	sched := runtime.LoadSchedulerOptsFromViper()
	runtime.StartScheduler(parent, moeRuntimeDeps(parent, svc), sched.SchedulerOpts, sched.Smart)
}
