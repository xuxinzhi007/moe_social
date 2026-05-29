package server

import (
	"backend/internal/platform/svc"
	adminapp "backend/internal/service/admin"
	moeadmin "backend/internal/service/moe"

	"gorm.io/gorm"
)

// PilotDeps Kratos HTTP 路由注册依赖。
type PilotDeps struct {
	MoeAdmin *moeadmin.AdminService
	AdminApp *adminapp.AppService
	Svc      *svc.ServiceContext
	DB       *gorm.DB
}

// Valid 是否可注册 HTTP 路由。
func (d PilotDeps) Valid() bool {
	return d.MoeAdmin != nil || d.AdminApp != nil || d.DB != nil || d.Svc != nil
}
