package moehttp

import (
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterAll 注册 PK-3 已迁移域的 Kratos HTTP 路由（与 go-zero :8888 路径一致）。
func RegisterAll(srv *khttp.Server, d PilotDeps) {
	if srv == nil || !d.Valid() {
		return
	}
	if d.MoeAdmin != nil {
		RegisterAdminCompat(srv, d.MoeAdmin)
	}
	if d.AdminApp != nil {
		RegisterAdminInsightsCompat(srv, d.AdminApp)
		RegisterAdminReadonlyCompat(srv, d.AdminApp)
	}
	if d.DB != nil {
		RegisterVipCompat(srv, d.DB)
	}
	if d.Svc != nil {
		RegisterLlmReadCompat(srv, d.Svc)
		RegisterLandingCompat(srv, d.Svc)
		RegisterCheckinCompat(srv, d.Svc)
		RegisterAchievementCompat(srv, d.Svc)
		RegisterBehaviorCompat(srv, d.Svc)
		RegisterGiftCompat(srv, d.Svc)
		RegisterCommentCompat(srv, d.Svc)
		RegisterUserLogicCompat(srv, d.Svc)
		RegisterWave2LogicCompat(srv, d.Svc)
		RegisterAdminLogicCompat(srv, d.Svc)
		RegisterPlatformLogicCompat(srv, d.Svc)
		RegisterNativeDomainHTTPHandlers(srv, d.Svc)
		RegisterBridgeHTTPHandlers(srv, d.Svc)
	}
}
