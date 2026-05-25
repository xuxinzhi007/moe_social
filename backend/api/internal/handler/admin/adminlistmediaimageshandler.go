// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/logic/admin"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminListMediaImagesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListMediaImagesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		publicBase := utils.ResolveMediaPublicBase(
			r,
			svcCtx.Config.Image.PublicBaseUrl,
			svcCtx.Config.ClientPublicApiBaseUrl,
		)
		l := admin.NewAdminListMediaImagesLogic(ctx, svcCtx)
		resp, err := l.AdminListMediaImages(&req, publicBase)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
