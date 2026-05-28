package giftgw

import (
	"context"

	giftapp "backend/internal/service/gift"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Gift HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *giftapp.AppService
	super moe.SuperClient
}

// New 构造网关。
func New(local *giftapp.AppService, legacy moe.SuperClient) *Gateway {
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

func (g *Gateway) GetGifts(ctx context.Context, in *moe.GetGiftsReq, opts ...grpc.CallOption) (*moe.GetGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGifts(ctx, in)
	}
	return g.super.GetGifts(ctx, in, opts...)
}

func (g *Gateway) GetGift(ctx context.Context, in *moe.GetGiftReq, opts ...grpc.CallOption) (*moe.GetGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGift(ctx, in)
	}
	return g.super.GetGift(ctx, in, opts...)
}

func (g *Gateway) SendGift(ctx context.Context, in *moe.SendGiftReq, opts ...grpc.CallOption) (*moe.SendGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendGift(ctx, in)
	}
	return g.super.SendGift(ctx, in, opts...)
}

func (g *Gateway) PurchaseGift(ctx context.Context, in *moe.PurchaseGiftReq, opts ...grpc.CallOption) (*moe.PurchaseGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.PurchaseGift(ctx, in)
	}
	return g.super.PurchaseGift(ctx, in, opts...)
}

func (g *Gateway) GetGiftRecords(ctx context.Context, in *moe.GetGiftRecordsReq, opts ...grpc.CallOption) (*moe.GetGiftRecordsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGiftRecords(ctx, in)
	}
	return g.super.GetGiftRecords(ctx, in, opts...)
}

func (g *Gateway) GetGiftPurchaseOrders(ctx context.Context, in *moe.GetGiftPurchaseOrdersReq, opts ...grpc.CallOption) (*moe.GetGiftPurchaseOrdersResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGiftPurchaseOrders(ctx, in)
	}
	return g.super.GetGiftPurchaseOrders(ctx, in, opts...)
}
