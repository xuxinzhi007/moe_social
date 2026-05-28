//go:build hybrid

// Code scaffolded by goctl. Safe to edit.

package user

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	userbiz "backend/internal/biz/user"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func FeishuOAuthCallbackHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.FeishuOAuthCallbackReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		userbiz.HandleFeishuOAuthCallback(w, r, userbiz.FeishuOAuthCallbackInput{
			Code: req.Code, State: req.State,
		})
	}
}
