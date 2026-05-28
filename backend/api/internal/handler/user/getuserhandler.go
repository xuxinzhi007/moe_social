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

func GetUserHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetUser(r.Context(), &moe.GetUserReq{UserId: req.UserId})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserResp{
			BaseResp: common.HandleRPCError(nil, "获取用户信息成功"),
			Data:     common.RpcUserToTypes(rpcResp.User),
		})
	}
}
