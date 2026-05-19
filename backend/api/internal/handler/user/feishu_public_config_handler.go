package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// FeishuPublicConfigHandler 飞书公开说明（邀请链接等，无需登录）。
func FeishuPublicConfigHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cfg := utils.GetFeishuPublicConfig()
		httpx.OkJsonCtx(r.Context(), w, &types.FeishuPublicConfigResp{
			BaseResp: common.HandleRPCError(nil, ""),
			Data: types.FeishuPublicConfigData{
				Enabled:             cfg.Enabled,
				EnterpriseInviteURL: cfg.EnterpriseInviteURL,
				Notice:              cfg.Notice,
			},
		})
	}
}
