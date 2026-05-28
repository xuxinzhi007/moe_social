package moewiring

import (
	"context"

	moebiz "backend/internal/biz/moe"
	"backend/internal/adapter/moeconfig"
	moedata "backend/internal/data/moe"
	moeadmin "backend/internal/service/moe"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/flowexec"
	"backend/pkg/moe/port"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/tools"
	"backend/rpc/pb/moe"
	"backend/utils"

	"gorm.io/gorm"
)

// NewAPIAdminService 在 API 进程装配 MoeAdmin（需已配置数据库）。
// superClient 与 appPort 二选一：P5 单进程用 appPort（Post/LLM App），分体部署用 Super gRPC。
func NewAPIAdminService(superClient moe.SuperClient, appPort port.SuperPort) (*moeadmin.AdminService, error) {
	var sp port.SuperPort
	switch {
	case appPort != nil:
		sp = appPort
	case superClient != nil:
		sp = port.GRPCAdapter{Client: superClient}
	default:
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	admin := moeadmin.NewAdmin(db)
	inf := moeconfig.InferenceFromViper()

	admin.AttachSuperPort(func(context.Context) port.SuperPort { return sp })
	admin.AttachRuntimeDeps(func(context.Context) runtime.Deps {
		return runtime.Deps{
			DB: db, RPC: sp, Inference: inf,
			ResolvePostingPlan: func(ctx context.Context, gdb *gorm.DB, agentKey string) (plan flowexec.Plan, err error) {
				return moebiz.ResolvePostingPlan(ctx, moedata.NewStore(gdb), agentKey)
			},
		}
	})
	admin.AttachBrainDeps(func(context.Context) brain.Deps {
		return brain.Deps{DB: db, RPC: sp}
	})
	admin.AttachBrainRefineDeps(func(context.Context) brain.RefineDeps {
		return brain.RefineDeps{DB: db, RPC: sp, Inference: inf}
	})
	admin.AttachToolsDeps(func(context.Context) tools.Deps {
		return tools.Deps{DB: db, RPC: sp, Inference: inf}
	})
	return admin, nil
}
