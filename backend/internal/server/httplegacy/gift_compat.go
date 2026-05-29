package httplegacy

import (
	"net/http"
	"strconv"

	giftv1 "backend/api/gift/v1"
	"backend/internal/platform/svc"
	"backend/internal/legacy/types"
	giftapp "backend/internal/service/gift"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeGiftCompatRoutes 礼物域 Kratos HTTP（internal/service/gift）。
const PilotNativeGiftCompatRoutes = 6

// RegisterGiftCompat D2：已迁入 RegisterGiftServiceHTTPServer。
func RegisterGiftCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	_ = srv
	_ = svcCtx
}

func giftRecordFromRPC(r *giftv1.GiftRecord) types.GiftRecord {
	if r == nil {
		return types.GiftRecord{}
	}
	rec := types.GiftRecord{
		Id: strconv.FormatUint(r.GetId(), 10),
		FromUserID: strconv.FormatUint(r.GetFromUserId(), 10),
		ToUserID:   strconv.FormatUint(r.GetToUserId(), 10),
		GiftID:     strconv.FormatUint(r.GetGiftId(), 10),
		Quantity:   int(r.GetQuantity()),
		CreatedAt:  r.GetCreatedAt(),
	}
	if g := r.GetGift(); g != nil {
		rec.Gift = giftFromRPC(g)
	}
	return rec
}

func giftFromRPC(g *giftv1.Gift) types.Gift {
	if g == nil {
		return types.Gift{}
	}
	return types.Gift{
		Id: strconv.FormatUint(g.GetId(), 10), Name: g.GetName(), Price: int(g.GetPrice()),
		Icon: g.GetIcon(), Description: g.GetDescription(), CreatedAt: g.GetCreatedAt(),
		UpdatedAt: g.GetUpdatedAt(), OwnedQuantity: int(g.GetOwnedQuantity()),
		Category: g.GetCategory(), SortOrder: int(g.GetSortOrder()),
	}
}

func giftList(app *giftapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGiftsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetGiftsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetGifts(ctx, &giftv1.GetGiftsRequest{
			Page: int32(req.Page), PageSize: int32(req.PageSize), ViewerUserId: req.UserId,
		})
		if err != nil {
			return err
		}
		gifts := make([]types.Gift, len(rpcResp.GetGifts()))
		for i, g := range rpcResp.GetGifts() {
			gifts[i] = giftFromRPC(g)
		}
		return ctx.JSON(http.StatusOK, types.GetGiftsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     gifts,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func giftGet(app *giftapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGiftReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetGiftResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetGift(ctx, &giftv1.GetGiftRequest{GiftId: req.GiftId})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.GetGiftResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     giftFromRPC(rpcResp.GetGift()),
		})
	}
}

func giftSend(app *giftapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SendGiftReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SendGiftResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.SendGift(ctx, &giftv1.SendGiftRequest{
			FromUserId: req.UserId, ToUserId: req.ToUserId, GiftId: req.GiftId, Quantity: int32(req.Quantity),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SendGiftResp{
				BaseResp: types.BaseResp{Code: 1, Message: err.Error(), Success: false},
			})
		}
		out := types.SendGiftResp{
			BaseResp: types.BaseResp{Code: 0, Message: rpcResp.GetMessage(), Success: rpcResp.GetSuccess()},
		}
		if rpcResp.GetSuccess() && rpcResp.GetRecord() != nil {
			out.Data = giftRecordFromRPC(rpcResp.GetRecord())
		}
		return ctx.JSON(http.StatusOK, out)
	}
}

func giftRecords(app *giftapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGiftRecordsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetGiftRecordsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetGiftRecords(ctx, &giftv1.GetGiftRecordsRequest{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return err
		}
		records := make([]types.GiftRecord, 0, len(rpcResp.GetRecords()))
		for _, rec := range rpcResp.GetRecords() {
			if rec == nil {
				continue
			}
			records = append(records, giftRecordFromRPC(rec))
		}
		return ctx.JSON(http.StatusOK, types.GetGiftRecordsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     records,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func giftPurchaseOrders(app *giftapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGiftPurchaseOrdersReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetGiftPurchaseOrdersResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetGiftPurchaseOrders(ctx, &giftv1.GetGiftPurchaseOrdersRequest{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return err
		}
		orders := make([]types.GiftPurchaseOrder, 0, len(rpcResp.GetOrders()))
		for _, o := range rpcResp.GetOrders() {
			if o == nil {
				continue
			}
			orders = append(orders, types.GiftPurchaseOrder{
				Id: o.GetId(), UserId: o.GetUserId(), OrderNo: o.GetOrderNo(),
				GiftId: o.GetGiftId(), GiftName: o.GetGiftName(), Quantity: int(o.GetQuantity()),
				UnitPrice: o.GetUnitPrice(), TotalAmount: o.GetTotalAmount(),
				PayMethod: o.GetPayMethod(), Status: o.GetStatus(), CreatedAt: o.GetCreatedAt(),
			})
		}
		return ctx.JSON(http.StatusOK, types.GetGiftPurchaseOrdersResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     orders,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func giftPurchase(app *giftapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.PurchaseGiftReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.PurchaseGiftResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.PurchaseGift(ctx, &giftv1.PurchaseGiftRequest{
			UserId: req.UserId, GiftId: req.GiftId, Quantity: int32(req.Quantity),
		})
		if err != nil {
			return err
		}
		if !rpcResp.GetSuccess() {
			return ctx.JSON(http.StatusOK, types.PurchaseGiftResp{
				BaseResp: types.BaseResp{Code: 0, Message: rpcResp.GetMessage(), Success: false},
				Data:     types.PurchaseGiftData{},
			})
		}
		return ctx.JSON(http.StatusOK, types.PurchaseGiftResp{
			BaseResp: types.BaseResp{Code: 0, Message: rpcResp.GetMessage(), Success: true},
			Data: types.PurchaseGiftData{
				NewBalance: rpcResp.GetNewBalance(), OwnedQuantity: int(rpcResp.GetOwnedQuantity()),
				OrderNo: rpcResp.GetOrderNo(),
			},
		})
	}
}
