package giftgw

import (
	"context"

	giftapp "backend/internal/service/gift"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

// Gateway Gift HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *giftapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *giftapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) GetGifts(ctx context.Context, in *super.GetGiftsReq, opts ...grpc.CallOption) (*super.GetGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGifts(ctx, in)
	}
	return g.super.GetGifts(ctx, in, opts...)
}

func (g *Gateway) GetGift(ctx context.Context, in *super.GetGiftReq, opts ...grpc.CallOption) (*super.GetGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGift(ctx, in)
	}
	return g.super.GetGift(ctx, in, opts...)
}

func (g *Gateway) SendGift(ctx context.Context, in *super.SendGiftReq, opts ...grpc.CallOption) (*super.SendGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendGift(ctx, in)
	}
	return g.super.SendGift(ctx, in, opts...)
}

func (g *Gateway) PurchaseGift(ctx context.Context, in *super.PurchaseGiftReq, opts ...grpc.CallOption) (*super.PurchaseGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.PurchaseGift(ctx, in)
	}
	return g.super.PurchaseGift(ctx, in, opts...)
}

func (g *Gateway) GetGiftRecords(ctx context.Context, in *super.GetGiftRecordsReq, opts ...grpc.CallOption) (*super.GetGiftRecordsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGiftRecords(ctx, in)
	}
	return g.super.GetGiftRecords(ctx, in, opts...)
}

func (g *Gateway) GetGiftPurchaseOrders(ctx context.Context, in *super.GetGiftPurchaseOrdersReq, opts ...grpc.CallOption) (*super.GetGiftPurchaseOrdersResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGiftPurchaseOrders(ctx, in)
	}
	return g.super.GetGiftPurchaseOrders(ctx, in, opts...)
}
