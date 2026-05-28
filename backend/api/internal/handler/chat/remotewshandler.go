package chat

import (
	"net/http"

	"backend/api/internal/svc"
	chatbiz "backend/internal/biz/chat"
)

// RemoteWsHandler WebSocket 远程通知通道。
func RemoteWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		chatbiz.ServeRemoteWS(w, r)
	}
}
