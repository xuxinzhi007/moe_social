//go:build hybrid

package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpdateUserPasswordHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpdateUserPasswordReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, err := svcCtx.UserGW.UpdateUserPassword(r.Context(), &moe.UpdateUserPasswordReq{
			UserId:      req.UserId,
			OldPassword: req.OldPassword,
			NewPassword: req.NewPassword,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.UpdateUserPasswordResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.UpdateUserPasswordResp{
			BaseResp: common.HandleRPCError(nil, "更新密码成功"),
		})
	}
}
