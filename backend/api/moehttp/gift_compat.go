package moehttp

import (
	"net/http"

	giftlogic "backend/api/internal/logic/gift"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativeGiftCompatRoutes 礼物域 Kratos HTTP（经 legacy logic 转 types，GW→service 已 in_process）。
const PilotNativeGiftCompatRoutes = 6

// RegisterGiftCompat 礼物相关 HTTP。
func RegisterGiftCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/gifts", giftList(svcCtx))
	r.GET("/api/gifts/:gift_id", giftGet(svcCtx))
	r.POST("/api/user/:user_id/gifts/send", giftSend(svcCtx))
	r.GET("/api/user/:user_id/gifts/records", giftRecords(svcCtx))
	r.GET("/api/user/:user_id/gifts/purchase-orders", giftPurchaseOrders(svcCtx))
	r.POST("/api/user/:user_id/gifts/purchase", giftPurchase(svcCtx))
}

func giftList(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGiftsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		l := giftlogic.NewGetGiftsLogic(ctx, svcCtx)
		resp, err := l.GetGifts(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func giftGet(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGiftReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		l := giftlogic.NewGetGiftLogic(ctx, svcCtx)
		resp, err := l.GetGift(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func giftSend(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SendGiftReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		l := giftlogic.NewSendGiftLogic(ctx, svcCtx)
		resp, err := l.SendGift(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func giftRecords(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGiftRecordsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		l := giftlogic.NewGetGiftRecordsLogic(ctx, svcCtx)
		resp, err := l.GetGiftRecords(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func giftPurchaseOrders(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGiftPurchaseOrdersReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		l := giftlogic.NewGetGiftPurchaseOrdersLogic(ctx, svcCtx)
		resp, err := l.GetGiftPurchaseOrders(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func giftPurchase(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.PurchaseGiftReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		l := giftlogic.NewPurchaseGiftLogic(ctx, svcCtx)
		resp, err := l.PurchaseGift(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}
