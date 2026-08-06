package apicomm

import (
	"net/http"
	"strings"

	"backend/common/errorcode"
	"backend/internal/legacy/types"
	"backend/utils"
)

// RequireAdminToken 解析 X-Admin-Token 或 Authorization: Bearer；失败返回 API BaseResp 错误语义。
func RequireAdminToken(r *http.Request) (*utils.AdminClaims, *types.BaseResp) {
	token := strings.TrimSpace(r.Header.Get("X-Admin-Token"))
	if token == "" && r != nil {
		token = strings.TrimSpace(r.URL.Query().Get("admin_token"))
	}
	if token == "" {
		auth := strings.TrimSpace(r.Header.Get("Authorization"))
		if len(auth) > 7 && auth[:7] == "Bearer " {
			token = auth[7:]
		}
	}
	if token == "" {
		return nil, &types.BaseResp{
			Code:    errorcode.E_UNAUTHORIZED,
			Message: "请先登录管理后台",
			Success: false,
		}
	}
	claims, err := utils.ParseAdminToken(token)
	if err != nil {
		return nil, &types.BaseResp{
			Code:    errorcode.E_UNAUTHORIZED,
			Message: "登录已过期，请重新登录",
			Success: false,
		}
	}
	return claims, nil
}
