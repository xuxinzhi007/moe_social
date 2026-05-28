package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CheckUserVipHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CheckUserVipReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.CheckUserVip(r.Context(), &moe.CheckUserVipReq{UserId: req.UserId})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.CheckUserVipResp{
				BaseResp: common.HandleUserGWError(err, ""),
				Data:     false,
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.CheckUserVipResp{
			BaseResp: common.HandleRPCError(nil, "检查用户VIP状态成功"),
			Data:     rpcResp.IsVip,
		})
	}
}
