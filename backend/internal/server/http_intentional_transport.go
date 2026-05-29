package server

import (
	"backend/internal/server/httplegacy"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterIntentionalTransportHTTP 注册有意保留的非 proto HTTP（OAuth 重定向 / SSE / WebSocket）。
// 长期方案见 docs/dev/kratos-intentional-transport.md。
func RegisterIntentionalTransportHTTP(srv *khttp.Server, d httplegacy.PilotDeps) {
	if srv == nil || !d.Valid() || d.Svc == nil {
		return
	}
	httplegacy.RegisterUserCompat(srv, d.Svc)
	httplegacy.RegisterChatCompat(srv, d.Svc)
	httplegacy.RegisterAdminLegacyCompat(srv, d.Svc)
}
