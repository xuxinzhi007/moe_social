// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package doc

import (
	"net/http"

	"backend/api/internal/logic/doc"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SwaggerDocHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l := doc.NewSwaggerDocLogic(r.Context(), svcCtx)
		if err := l.SwaggerDoc(w); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		}
	}
}
