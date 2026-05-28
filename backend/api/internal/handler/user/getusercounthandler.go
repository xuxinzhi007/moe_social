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

func GetUserCountHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetUserCount(r.Context(), &moe.GetUserCountReq{})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserCountResp{
				BaseResp: common.HandleRPCError(err, ""),
				Data:     0,
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserCountResp{
			BaseResp: common.HandleRPCError(nil, "获取用户数量成功"),
			Data:     int(rpcResp.Count),
		})
	}
}
