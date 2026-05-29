package server

import (
	"backend/internal/server/httplegacy"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterCompatHTTP 按域注册存量 compat HTTP（S3：编排入口在 server 层）。
// 实现仍委托 internal/server/httplegacy/*_compat.go，随 proto HTTP 逐域删除。
func RegisterCompatHTTP(srv *khttp.Server, d httplegacy.PilotDeps) {
	if srv == nil || !d.Valid() {
		return
	}
	registerAdminHTTP(srv, d)
	registerInsightsHTTP(srv, d)
	registerVipHTTP(srv, d)
	registerSvcDomainsHTTP(srv, d)
}

func registerAdminHTTP(srv *khttp.Server, d httplegacy.PilotDeps) {
	if d.MoeAdmin != nil {
		httplegacy.RegisterAdminCompat(srv, d.MoeAdmin)
	}
}

func registerInsightsHTTP(srv *khttp.Server, d httplegacy.PilotDeps) {
	if d.AdminApp == nil {
		return
	}
	httplegacy.RegisterAdminInsightsCompat(srv, d.AdminApp)
	httplegacy.RegisterAdminReadonlyCompat(srv, d.AdminApp)
}

func registerVipHTTP(srv *khttp.Server, d httplegacy.PilotDeps) {
	if d.DB != nil {
		httplegacy.RegisterVipCompat(srv, d.DB)
	}
}

func registerSvcDomainsHTTP(srv *khttp.Server, d httplegacy.PilotDeps) {
	if d.Svc == nil {
		return
	}
	httplegacy.RegisterLlmReadCompat(srv, d.Svc)
	httplegacy.RegisterLandingCompat(srv, d.Svc)
	httplegacy.RegisterCheckinCompat(srv, d.Svc)
	httplegacy.RegisterAchievementCompat(srv, d.Svc)
	httplegacy.RegisterBehaviorCompat(srv, d.Svc)
	httplegacy.RegisterGiftCompat(srv, d.Svc)
	httplegacy.RegisterCommentCompat(srv, d.Svc)
	httplegacy.RegisterPostCompat(srv, d.Svc)
	httplegacy.RegisterCommunityCompat(srv, d.Svc)
	httplegacy.RegisterUserCompat(srv, d.Svc)
	httplegacy.RegisterUserMemoryCompat(srv, d.Svc)
	httplegacy.RegisterAiCompat(srv, d.Svc)
	httplegacy.RegisterChatCompat(srv, d.Svc)
	httplegacy.RegisterWave2MiscCompat(srv, d.Svc)
	httplegacy.RegisterAdminServiceCompat(srv, d.Svc)
	httplegacy.RegisterAdminLegacyCompat(srv, d.Svc)
	httplegacy.RegisterPlatformCompat(srv, d.Svc)
	httplegacy.RegisterNativeDomainHTTPHandlers(srv, d.Svc)
	httplegacy.RegisterBridgeHTTPHandlers(srv, d.Svc)
}
