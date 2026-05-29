package server

import (
	"backend/internal/server/transport"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterTransportHTTP 注册 OAuth / WebSocket / SSE（Kratos transport 层，与 proto HTTP 同进程管理）。
func RegisterTransportHTTP(srv *khttp.Server, d PilotDeps) {
	if srv == nil || !d.Valid() || d.Svc == nil {
		return
	}
	transport.RegisterHTTP(srv, d.Svc)
}
