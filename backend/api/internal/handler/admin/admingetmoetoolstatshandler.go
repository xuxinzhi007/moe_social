package admin

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/logic/admin"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminGetMoeToolStatsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminGetMoeToolStatsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		l := admin.NewAdminGetMoeToolStatsLogic(ctx, svcCtx)
		resp, err := l.AdminGetMoeToolStats(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		httpx.OkJsonCtx(ctx, w, resp)
	}
}
