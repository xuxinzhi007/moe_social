//go:build hybrid

package gift

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetGiftPurchaseOrdersHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetGiftPurchaseOrdersReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.GiftGW.GetGiftPurchaseOrders(r.Context(), &moe.GetGiftPurchaseOrdersReq{
			UserId:   req.UserId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetGiftPurchaseOrdersResp{
				BaseResp: common.HandleRPCError(err, ""),
				Data:     nil,
				Total:    0,
			})
			return
		}

		data := make([]types.GiftPurchaseOrder, 0, len(rpcResp.Orders))
		for _, o := range rpcResp.Orders {
			data = append(data, types.GiftPurchaseOrder{
				Id:          o.Id,
				UserId:      o.UserId,
				OrderNo:     o.OrderNo,
				GiftId:      o.GiftId,
				GiftName:    o.GiftName,
				Quantity:    int(o.Quantity),
				UnitPrice:   o.UnitPrice,
				TotalAmount: o.TotalAmount,
				PayMethod:   o.PayMethod,
				Status:      o.Status,
				CreatedAt:   o.CreatedAt,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetGiftPurchaseOrdersResp{
			BaseResp: common.HandleRPCError(nil, "获取礼物购买订单成功"),
			Data:     data,
			Total:    int(rpcResp.Total),
		})
	}
}
