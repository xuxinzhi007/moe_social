// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package privatemsg

import (
	"net/http"

	"backend/api/internal/logic/privatemsg"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func SendPrivateMessageHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SendPrivateMessageReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := privatemsg.NewSendPrivateMessageLogic(r.Context(), svcCtx)
		resp, err := l.SendPrivateMessage(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
