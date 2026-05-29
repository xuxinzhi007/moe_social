package transport

import (
	"backend/internal/platform/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// HTTP route counts（OAuth / WebSocket / SSE；与 routestats 同步）。
const (
	OAuthRoutes     = 2
	WebSocketRoutes = 5
	SSERoutes       = 1
	RouteCount      = OAuthRoutes + WebSocketRoutes + SSERoutes
)

// RegisterHTTP 注册非 JSON proto 的 Kratos HTTP transport（OAuth 重定向 / WebSocket / SSE）。
func RegisterHTTP(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	r := srv.Route("/")
	registerOAuth(r)
	registerWebSocket(r, svc)
	registerSSE(r, svc)
}
