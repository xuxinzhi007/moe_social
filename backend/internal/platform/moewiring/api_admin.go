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

// NewAPIAdminService 在 API 进程装配 MoeAdmin（需已配置数据库；Super 走 gRPC 客户端）。
func NewAPIAdminService(superClient moe.SuperClient) (*moeadmin.AdminService, error) {
	if superClient == nil {
		return nil, nil
	}
	// api_in_process 需在 API 进程连库；未配置库时返回 error，由 moe.go 降级为纯 RPC。
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	admin := moeadmin.NewAdmin(db)
	grpcPort := port.GRPCAdapter{Client: superClient}
	inf := moeconfig.InferenceFromViper()

	admin.AttachSuperPort(func(context.Context) port.SuperPort { return grpcPort })
	admin.AttachRuntimeDeps(func(context.Context) runtime.Deps {
		return runtime.Deps{
			DB: db, RPC: grpcPort, Inference: inf,
			ResolvePostingPlan: func(ctx context.Context, gdb *gorm.DB, agentKey string) (plan flowexec.Plan, err error) {
				return moebiz.ResolvePostingPlan(ctx, moedata.NewStore(gdb), agentKey)
			},
		}
	})
	admin.AttachBrainDeps(func(context.Context) brain.Deps {
		return brain.Deps{DB: db, RPC: grpcPort}
	})
	admin.AttachBrainRefineDeps(func(context.Context) brain.RefineDeps {
		return brain.RefineDeps{DB: db, RPC: grpcPort, Inference: inf}
	})
	admin.AttachToolsDeps(func(context.Context) tools.Deps {
		return tools.Deps{DB: db, RPC: grpcPort, Inference: inf}
	})
	return admin, nil
}
