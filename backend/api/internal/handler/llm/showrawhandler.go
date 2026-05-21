// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package llm

import (
	"net/http"

	"backend/api/internal/logic/llm"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ShowRawHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l := llm.NewShowRawLogic(r.Context(), svcCtx)
		if err := l.ShowRaw(w, r); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		}
	}
}
