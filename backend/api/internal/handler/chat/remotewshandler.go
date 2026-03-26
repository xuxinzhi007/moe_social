// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package chat

import (
	"net/http"

	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// WebSocket远程控制服务
func RemoteWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l := chat.NewRemoteWsLogic(r.Context(), svcCtx)
		err := l.RemoteWs()
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.Ok(w)
		}
	}
}
