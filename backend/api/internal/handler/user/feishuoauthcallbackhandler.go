// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"net/http"

	"backend/api/internal/logic/user"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func FeishuOAuthCallbackHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.FeishuOAuthCallbackReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := user.NewFeishuOAuthCallbackLogic(r.Context(), svcCtx)
		if err := l.FeishuOAuthCallback(w, r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		}
	}
}
