// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package llm

import (
	"net/http"

	"backend/api/internal/logic/llm"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func LocalModelsCatalogHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := llm.NewLocalModelsCatalogLogic(r.Context(), svcCtx)
		resp, err := l.LocalModelsCatalog(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
