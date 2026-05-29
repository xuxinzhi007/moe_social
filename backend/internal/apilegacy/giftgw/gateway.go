package giftgw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	giftv1 "backend/api/gift/v1"
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
		out, err := g.local.GetGifts(ctx, giftv1.GetGiftsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return giftv1.GetGiftsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGift(ctx context.Context, in *moe.GetGiftReq, opts ...grpc.CallOption) (*moe.GetGiftResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetGift(ctx, giftv1.GetGiftRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return giftv1.GetGiftReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SendGift(ctx context.Context, in *moe.SendGiftReq, opts ...grpc.CallOption) (*moe.SendGiftResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SendGift(ctx, giftv1.SendGiftRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return giftv1.SendGiftReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) PurchaseGift(ctx context.Context, in *moe.PurchaseGiftReq, opts ...grpc.CallOption) (*moe.PurchaseGiftResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.PurchaseGift(ctx, giftv1.PurchaseGiftRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return giftv1.PurchaseGiftReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGiftRecords(ctx context.Context, in *moe.GetGiftRecordsReq, opts ...grpc.CallOption) (*moe.GetGiftRecordsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetGiftRecords(ctx, giftv1.GetGiftRecordsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return giftv1.GetGiftRecordsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGiftPurchaseOrders(ctx context.Context, in *moe.GetGiftPurchaseOrdersReq, opts ...grpc.CallOption) (*moe.GetGiftPurchaseOrdersResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetGiftPurchaseOrders(ctx, giftv1.GetGiftPurchaseOrdersRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return giftv1.GetGiftPurchaseOrdersReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
