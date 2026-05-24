// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"net/http"

	"backend/api/internal/logic/admin"
	"backend/api/internal/svc"

	"backend/api/internal/common"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminUpdateGiftHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminUpdateGiftResp{BaseResp: *br})
			return
		}

		var req types.AdminUpdateGiftReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := admin.NewAdminUpdateGiftLogic(r.Context(), svcCtx)
		resp, err := l.AdminUpdateGift(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
