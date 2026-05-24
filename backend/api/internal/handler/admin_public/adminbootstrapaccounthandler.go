// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin_public

import (
	"net/http"

	"backend/api/internal/logic/admin_public"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminBootstrapAccountHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := admin_public.NewAdminBootstrapAccountLogic(r.Context(), svcCtx)
		resp, err := l.AdminBootstrapAccount(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
