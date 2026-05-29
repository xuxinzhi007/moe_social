package httplegacy

import (
	"backend/internal/platform/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeAdminLegacyCompatRoutes P1：仅保留 SSE 流水线（proto 不支持 stream）。
const PilotNativeAdminLegacyCompatRoutes = 1

// RegisterAdminLegacyCompat P1：已迁入 RegisterAdminAppHTTPServer + RegisterMoeAdminHTTPServer。
// 保留 GET /api/admin/moe/brain/pipeline/stream（SSE tier-A）。
func RegisterAdminLegacyCompat(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	admin := svc.MoeAdmin
	r := srv.Route("/")
	r.GET("/api/admin/moe/brain/pipeline/stream", adminStreamMoeBrainPipeline(admin))
}
