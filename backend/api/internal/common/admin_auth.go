package common

import (
	"net/http"
	"strings"

	"backend/api/internal/types"
	"backend/common/errorcode"
	"backend/utils"
)

// RequireAdminToken 解析 X-Admin-Token；失败返回 API BaseResp 错误语义。
func RequireAdminToken(r *http.Request) (*utils.AdminClaims, *types.BaseResp) {
	token := strings.TrimSpace(r.Header.Get("X-Admin-Token"))
	if token == "" && r != nil {
		token = strings.TrimSpace(r.URL.Query().Get("admin_token"))
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
