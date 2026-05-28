package moekratospilot

import (
	"backend/api/internal/svc"
	adminapp "backend/internal/service/admin"
	moeadmin "backend/internal/service/moe"

	"gorm.io/gorm"
)

// PilotDeps 纯 Kratos 试点/前置层依赖（PK-3/4）。
type PilotDeps struct {
	MoeAdmin  *moeadmin.AdminService
	AdminApp  *adminapp.AppService
	Svc       *svc.ServiceContext
	DB        *gorm.DB
}

// Valid 是否可注册试点路由。
func (d PilotDeps) Valid() bool {
	return d.MoeAdmin != nil || d.AdminApp != nil || d.DB != nil || d.Svc != nil
}
