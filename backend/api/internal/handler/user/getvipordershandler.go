package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetVipOrdersHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetVipOrdersReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetVipOrders(r.Context(), &moe.GetVipOrdersReq{
			UserId:   req.UserId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetVipOrdersResp{
				BaseResp: common.HandleRPCError(err, ""),
				Data:     nil,
				Total:    0,
			})
			return
		}

		respOrders := make([]types.VipOrder, 0, len(rpcResp.Orders))
		for _, order := range rpcResp.Orders {
			respOrders = append(respOrders, types.VipOrder{
				Id:        order.Id,
				UserId:    order.UserId,
				PlanId:    order.PlanId,
				PlanName:  order.PlanName,
				Amount:    float64(order.Amount),
				Status:    order.Status,
				CreatedAt: order.CreatedAt,
				PaidAt:    order.PaidAt,
				OrderNo:   order.OrderNo,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetVipOrdersResp{
			BaseResp: common.HandleRPCError(nil, "获取VIP订单列表成功"),
			Data:     respOrders,
			Total:    int(rpcResp.Total),
		})
	}
}
