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

func GetUsersHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUsersReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetUsers(r.Context(), &moe.GetUsersReq{
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUsersResp{
				BaseResp: common.HandleRPCError(err, ""),
				Data:     nil,
				Total:    0,
			})
			return
		}

		respUsers := make([]types.User, 0, len(rpcResp.Users))
		for _, u := range rpcResp.Users {
			respUsers = append(respUsers, common.RpcUserToTypes(u))
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUsersResp{
			BaseResp: common.HandleRPCError(nil, "获取用户列表成功"),
			Data:     respUsers,
			Total:    int(rpcResp.Total),
		})
	}
}
