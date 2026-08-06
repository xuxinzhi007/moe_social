package moewiring

import (
	"context"

	"backend/internal/adapter/moeconfig"
	moebiz "backend/internal/biz/moe"
	moedata "backend/internal/data/moe"
	"backend/internal/platform/appdb"
	moeadmin "backend/internal/service/moe"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/flowexec"
	"backend/pkg/moe/port"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/tools"

	"gorm.io/gorm"
)

// NewAPIAdminService 在 API 进程装配 MoeAdmin（需已配置数据库）。
func NewAPIAdminService(appPort port.MoeToolPort) (*moeadmin.AdminService, error) {
	if appPort == nil {
		return nil, nil
	}
	sp := appPort
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	admin := moeadmin.NewAdmin(db)
	inf := moeconfig.InferenceFromViper()

	admin.AttachMoeToolPort(func(context.Context) port.MoeToolPort { return sp })
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
