package transport

import (
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const (
	OAuthRoutes     = 2
	AppRoutes       = 1
	WebSocketRoutes = 8
	SSERoutes       = 1
	RouteCount      = OAuthRoutes + AppRoutes + WebSocketRoutes + SSERoutes
)

func RegisterHTTP(srv *khttp.Server, deps Deps) {
	if srv == nil {
		return
	}
	r := srv.Route("/")
	registerOAuth(r)
	registerAppRoutes(r, deps.MoeAdmin)
	registerWebSocket(r, deps)
	registerSSE(r, deps.MoeAdmin)
}
