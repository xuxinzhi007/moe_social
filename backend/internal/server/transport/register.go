package transport

import (
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func RegisterHTTP(srv *khttp.Server, deps Deps) {
	if srv == nil {
		return
	}
	r := srv.Route("/")
	RegisterOAuth(r)
	registerAppRoutes(r, deps.MoeAdmin)
	registerWebSocket(r, deps)
	registerSSE(r, deps.MoeAdmin)
}
