//go:build hybrid

package user

import (
	"errors"
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	userbiz "backend/internal/biz/user"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// RefreshTokenHandler 用 Header Authorization: Bearer <当前 access token> 换取新 token。
func RefreshTokenHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		tok, err := userbiz.RefreshAccessToken(r.Header.Get("Authorization"))
		if err != nil {
			switch {
			case errors.Is(err, userbiz.ErrMissingAuthorization):
				httpx.WriteJsonCtx(r.Context(), w, http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "缺少 Authorization", Success: false})
			case errors.Is(err, userbiz.ErrInvalidAuthorizationFormat):
				httpx.WriteJsonCtx(r.Context(), w, http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "Authorization 格式应为 Bearer <token>", Success: false})
			case errors.Is(err, userbiz.ErrMissingToken):
				httpx.WriteJsonCtx(r.Context(), w, http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "缺少 token", Success: false})
			default:
				httpx.WriteJsonCtx(r.Context(), w, http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "令牌无效或已过期", Success: false})
			}
			return
		}
		httpx.OkJsonCtx(r.Context(), w, &types.RefreshTokenResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     types.RefreshTokenData{Token: tok},
		})
	}
}
