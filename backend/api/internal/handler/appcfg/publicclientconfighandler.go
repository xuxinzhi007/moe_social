//go:build hybrid

package appcfg

import (
	"errors"
	"net/http"

	appcfgbiz "backend/internal/biz/appcfg"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func PublicClientConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		url, err := appcfgbiz.NormalizePublicAPIBaseURL(svcCtx.Config.ClientPublicApiBaseUrl)
		if err != nil {
			if errors.Is(err, appcfgbiz.ErrNoPublicAPIBaseURL) {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.PublicClientConfigResp{ApiBaseUrl: url})
	}
}
