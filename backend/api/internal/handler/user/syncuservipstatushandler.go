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

func SyncUserVipStatusHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SyncUserVipStatusReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.SyncUserVipStatus(r.Context(), &moe.SyncUserVipStatusReq{UserId: req.UserId})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SyncUserVipStatusResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.SyncUserVipStatusResp{
			BaseResp: common.HandleRPCError(nil, "同步用户VIP状态成功"),
			Data: types.SyncUserVipStatusData{
				IsVip:     rpcResp.IsVip,
				ExpiresAt: rpcResp.ExpiresAt,
			},
		})
	}
}
