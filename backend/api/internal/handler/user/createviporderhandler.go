//go:build hybrid

package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CreateVipOrderHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CreateVipOrderReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.CreateVipOrder(r.Context(), &moe.CreateVipOrderReq{
			UserId: req.UserId,
			PlanId: req.PlanId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.CreateVipOrderResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.CreateVipOrderResp{
			BaseResp:        common.HandleRPCError(nil, "创建VIP订单成功"),
			NewAchievements: handlerutil.UnlocksFromRPC(rpcResp.NewAchievements),
			Data: types.VipOrder{
				Id:        rpcResp.Order.Id,
				UserId:    rpcResp.Order.UserId,
				PlanId:    rpcResp.Order.PlanId,
				PlanName:  rpcResp.Order.PlanName,
				Amount:    float64(rpcResp.Order.Amount),
				Status:    rpcResp.Order.Status,
				CreatedAt: rpcResp.Order.CreatedAt,
				PaidAt:    rpcResp.Order.PaidAt,
				OrderNo:   rpcResp.Order.OrderNo,
			},
		})
	}
}
