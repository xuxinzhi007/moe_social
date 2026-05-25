// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/logic/admin"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminListAuditLogsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListAuditLogsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := admin.NewAdminListAuditLogsLogic(ctx, svcCtx)
		resp, err := l.AdminListAuditLogs(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
