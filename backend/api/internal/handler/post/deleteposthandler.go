// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package post

import (
	"fmt"
	"net/http"

	"backend/api/internal/logic/post"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func DeletePostHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, err := parseJWTClaims(r)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		var req types.DeletePostReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		req.UserId = fmt.Sprintf("%d", claims.UserID)

		l := post.NewDeletePostLogic(r.Context(), svcCtx)
		resp, err := l.DeletePost(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
