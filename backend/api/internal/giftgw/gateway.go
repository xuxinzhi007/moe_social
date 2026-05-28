package giftgw

import (
	"backend/api/internal/gwutil"
	"context"

	giftapp "backend/internal/service/gift"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Gift HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *giftapp.AppService
}

// New 构造网关。
func New(local *giftapp.AppService) *Gateway {
	return &Gateway{local: local}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) GetGifts(ctx context.Context, in *moe.GetGiftsReq, opts ...grpc.CallOption) (*moe.GetGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGifts(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGift(ctx context.Context, in *moe.GetGiftReq, opts ...grpc.CallOption) (*moe.GetGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGift(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SendGift(ctx context.Context, in *moe.SendGiftReq, opts ...grpc.CallOption) (*moe.SendGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendGift(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) PurchaseGift(ctx context.Context, in *moe.PurchaseGiftReq, opts ...grpc.CallOption) (*moe.PurchaseGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.PurchaseGift(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGiftRecords(ctx context.Context, in *moe.GetGiftRecordsReq, opts ...grpc.CallOption) (*moe.GetGiftRecordsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGiftRecords(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGiftPurchaseOrders(ctx context.Context, in *moe.GetGiftPurchaseOrdersReq, opts ...grpc.CallOption) (*moe.GetGiftPurchaseOrdersResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetGiftPurchaseOrders(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
