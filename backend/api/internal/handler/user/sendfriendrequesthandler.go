// Code scaffolded by goctl; 业务委托给 FriendLogic（需 *http.Request 解析 JWT）
package user

import (
	"net/http"

	"backend/api/internal/logic/user"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SendFriendRequestHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SendFriendRequestReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := user.NewFriendLogic(r.Context(), svcCtx)
		resp, err := l.SendFriendRequest(r, &req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
