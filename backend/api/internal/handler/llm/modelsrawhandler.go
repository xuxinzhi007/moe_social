// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package llm

import (
	"net/http"

	"backend/api/internal/logic/llm"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ModelsRawHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l := llm.NewModelsRawLogic(r.Context(), svcCtx)
		if err := l.ModelsRaw(w, r); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		}
	}
}
