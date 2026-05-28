package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpdateUserVipHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpdateUserVipReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.UpdateUserVip(r.Context(), &moe.UpdateUserVipReq{
			UserId:     req.UserId,
			IsVip:      req.IsVip,
			VipExpires: req.VipExpires,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.UpdateUserVipResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.UpdateUserVipResp{
			BaseResp: common.HandleRPCError(nil, "更新用户VIP状态成功"),
			Data:     common.RpcUserToTypes(rpcResp.User),
		})
	}
}
