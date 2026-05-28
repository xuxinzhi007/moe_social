package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func FeishuPublicConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

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
