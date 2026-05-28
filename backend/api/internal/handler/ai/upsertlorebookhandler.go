package ai

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpsertLorebookHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AiLorebookUpsertReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		userID, err := common.UserIDUint(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		full, err := handlerutil.AIUpsertLorebook(r.Context(), svcCtx, userID, req.Data, req.Entries)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, &full.BaseResp)
		}
	}
}
