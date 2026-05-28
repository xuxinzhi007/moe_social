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

func GetUserInfoHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserInfoReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetUserInfo(r.Context(), &moe.GetUserInfoReq{UserId: req.UserId})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserInfoResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserInfoResp{
			BaseResp: common.HandleRPCError(nil, "获取用户信息成功"),
			Data:     common.RpcUserToTypes(rpcResp.User),
		})
	}
}
