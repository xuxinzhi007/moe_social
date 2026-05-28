package ai

import (
	"errors"
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func DeleteLorebookHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AiResourceDeleteReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		if req.Id == "" {
			httpx.ErrorCtx(r.Context(), w, errors.New("missing lorebook id"))
			return
		}
		userID, err := common.UserIDUint(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		full, err := handlerutil.AIDeleteLorebook(r.Context(), svcCtx, userID, req.Id)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, &full.BaseResp)
		}
	}
}
