package user

import (
	"net/http"
	"strings"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// RefreshTokenHandler 用 Header Authorization: Bearer <当前 access token> 换取新 token（延长有效期）。
// 令牌须仍在有效期内且签名校验通过；新 token 的声明与登录一致（user_id、username、exp/iat/nbf）。
func RefreshTokenHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := strings.TrimSpace(r.Header.Get("Authorization"))
		if auth == "" {
			httpx.WriteJsonCtx(r.Context(), w, http.StatusUnauthorized, types.BaseResp{
				Code:    401,
				Message: "缺少 Authorization",
				Success: false,
			})
			return
		}
		parts := strings.SplitN(auth, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			httpx.WriteJsonCtx(r.Context(), w, http.StatusUnauthorized, types.BaseResp{
				Code:    401,
				Message: "Authorization 格式应为 Bearer <token>",
				Success: false,
			})
			return
		}
		tokenStr := strings.TrimSpace(parts[1])
		if tokenStr == "" {
			httpx.WriteJsonCtx(r.Context(), w, http.StatusUnauthorized, types.BaseResp{
				Code:    401,
				Message: "缺少 token",
				Success: false,
			})
			return
		}

		claims, err := utils.ParseToken(tokenStr)
		if err != nil {
			httpx.WriteJsonCtx(r.Context(), w, http.StatusUnauthorized, types.BaseResp{
				Code:    401,
				Message: "令牌无效或已过期",
				Success: false,
			})
			return
		}

		newTok, err := utils.GenerateToken(claims.UserID, claims.Username)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.RefreshTokenResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: "ok",
				Success: true,
			},
			Data: types.RefreshTokenData{Token: newTok},
		})
	}
}
