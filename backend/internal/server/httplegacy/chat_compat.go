package httplegacy

import (
	"backend/internal/platform/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeChatCompatRoutes WebSocket 入口（有意保留 compat；REST 在线已迁入 ChatPresenceService）。
const PilotNativeChatCompatRoutes = 4

// RegisterChatCompat 注册 WebSocket 路由（见 chat_ws_compat.go）。
func RegisterChatCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/ws/chat", chatWSHandler(svcCtx))
	r.GET("/ws/presence", chatPresenceWSHandler())
	r.GET("/ws/remote", chatRemoteWS())
	r.GET("/ws/world", chatWorldWSHandler())
}
