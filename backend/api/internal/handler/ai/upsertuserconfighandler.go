// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package ai

import (
	"net/http"

	"backend/api/internal/logic/ai"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpsertUserConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AiUserConfigReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := ai.NewUpsertUserConfigLogic(r.Context(), svcCtx)
		resp, err := l.UpsertUserConfig(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
