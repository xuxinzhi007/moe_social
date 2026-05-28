package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserVipStatusHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserActiveVipRecordReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetUserVipStatus(r.Context(), &moe.GetUserVipStatusReq{UserId: req.UserId})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserVipStatusResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserVipStatusResp{
			BaseResp: common.HandleRPCError(nil, "获取用户VIP状态成功"),
			Data: types.UserVipStatusData{
				IsVip:     rpcResp.IsVip,
				ExpiresAt: rpcResp.ExpiresAt,
				AutoRenew: rpcResp.AutoRenew,
			},
		})
	}
}
