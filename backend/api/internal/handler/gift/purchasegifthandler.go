package gift

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func PurchaseGiftHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.PurchaseGiftReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		qty := int32(req.Quantity)
		if qty <= 0 {
			qty = 1
		}
		rpcResp, err := svcCtx.GiftGW.PurchaseGift(r.Context(), &moe.PurchaseGiftReq{
			UserId:   req.UserId,
			GiftId:   req.GiftId,
			Quantity: qty,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		if !rpcResp.Success {
			httpx.OkJsonCtx(r.Context(), w, &types.PurchaseGiftResp{
				BaseResp: types.BaseResp{Code: 0, Message: rpcResp.Message, Success: false},
				Data:     types.PurchaseGiftData{},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.PurchaseGiftResp{
			BaseResp: types.BaseResp{Code: 0, Message: rpcResp.Message, Success: true},
			Data: types.PurchaseGiftData{
				NewBalance:    rpcResp.NewBalance,
				OwnedQuantity: int(rpcResp.OwnedQuantity),
				OrderNo:       rpcResp.OrderNo,
			},
		})
	}
}
