package logic

import (
	"context"

	"backend/internal/adapter/rpcsuper"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/tools"
	"backend/rpc/internal/svc"
)

// AttachMoeAdminHooks 向 MoeAdmin 注入 RPC 侧依赖（避免 svc ↔ logic 循环 import）。
func AttachMoeAdminHooks(svcCtx *svc.ServiceContext) {
	if svcCtx == nil || svcCtx.MoeAdmin == nil {
		return
	}
	bridge := newSuperBridge(svcCtx)
	svcCtx.MoeAdmin.AttachRuntimeDeps(func(ctx context.Context) runtime.Deps {
		return moeRuntimeDeps(ctx, svcCtx)
	})
	svcCtx.MoeAdmin.AttachSuperPort(func(ctx context.Context) port.SuperPort {
		return rpcsuper.NewSuperPort(ctx, bridge)
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
