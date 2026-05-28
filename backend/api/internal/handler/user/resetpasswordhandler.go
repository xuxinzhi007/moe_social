//go:build hybrid

package user

import (
	"errors"
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ResetPasswordHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ResetPasswordReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		if req.Email == "" {
			httpx.OkJsonCtx(r.Context(), w, &types.ResetPasswordResp{
				BaseResp: common.HandleError(errors.New("邮箱不能为空")),
			})
			return
		}
		if req.NewPassword == "" {
			httpx.OkJsonCtx(r.Context(), w, &types.ResetPasswordResp{
				BaseResp: common.HandleError(errors.New("新密码不能为空")),
			})
			return
		}

		_, err := svcCtx.UserGW.ResetPassword(r.Context(), &moe.ResetPasswordReq{
			Email:       req.Email,
			NewPassword: req.NewPassword,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ResetPasswordResp{
				BaseResp: common.HandleRPCError(err, "重置密码失败"),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ResetPasswordResp{
			BaseResp: common.HandleRPCError(nil, "重置密码成功"),
		})
	}
}
