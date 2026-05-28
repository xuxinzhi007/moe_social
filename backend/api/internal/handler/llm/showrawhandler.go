package llm

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ShowRawHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := handlerutil.LLMShowRaw(r.Context(), svcCtx, w, r); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		}
	}
}
