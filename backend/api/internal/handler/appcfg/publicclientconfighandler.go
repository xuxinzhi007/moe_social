package appcfg

import (
	"errors"
	"net/http"

	appcfglogic "backend/api/internal/logic/appcfg"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// PublicClientConfigHandler 无鉴权；业务在 logic，404 与 JSON 形状与历史实现一致。
func PublicClientConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := appcfglogic.NewPublicClientConfigLogic(r.Context(), svcCtx)
		resp, err := l.PublicClientConfig(&req)
		if err != nil {
			if errors.Is(err, appcfglogic.ErrNoPublicAPIBaseURL) {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
