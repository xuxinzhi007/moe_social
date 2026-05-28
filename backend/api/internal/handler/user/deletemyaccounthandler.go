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

func DeleteMyAccountHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		userID, err := common.UserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, err = svcCtx.UserGW.DeleteUser(r.Context(), &moe.DeleteUserReq{UserId: userID})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.DeleteUserResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.DeleteUserResp{
			BaseResp: common.HandleRPCError(nil, "账号已注销"),
		})
	}
}
