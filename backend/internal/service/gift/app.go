// Package giftapp 礼物域应用服务。
package giftapp

import (
	"context"

	giftv1 "backend/api/gift/v1"
	giftbiz "backend/internal/biz/gift"
	giftdata "backend/internal/data/gift"

	"gorm.io/gorm"
)

// AppService 礼物应用层。
type AppService struct {
	store giftbiz.GiftStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: giftdata.NewStore(db)}
}

func (s *AppService) GetGifts(ctx context.Context, in *giftv1.GetGiftsRequest) (*giftv1.GetGiftsReply, error) {
	gifts, total, err := giftbiz.ListGifts(ctx, s.store, in.GetPage(), in.GetPageSize(), in.GetViewerUserId())
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftsReply{Gifts: giftv1.GiftsFromMoe(gifts), Total: total}, nil
}

func (s *AppService) GetGift(ctx context.Context, in *giftv1.GetGiftRequest) (*giftv1.GetGiftReply, error) {
	resp, err := giftbiz.GetGift(ctx, s.store, in.GetGiftId())
	if err != nil {
		return nil, err
	}
	return giftv1.GetGiftReplyFromMoe(resp), nil
}

func (s *AppService) SendGift(ctx context.Context, in *giftv1.SendGiftRequest) (*giftv1.SendGiftReply, error) {
	resp, err := giftbiz.Send(ctx, s.store, in.GetFromUserId(), in.GetToUserId(), in.GetGiftId(), in.GetQuantity())
	if err != nil {
		return nil, err
	}
	return giftv1.SendGiftReplyFromMoe(resp), nil
}

func (s *AppService) PurchaseGift(ctx context.Context, in *giftv1.PurchaseGiftRequest) (*giftv1.PurchaseGiftReply, error) {
	resp, err := giftbiz.Purchase(ctx, s.store, in.GetUserId(), in.GetGiftId(), in.GetQuantity())
	if err != nil {
		return nil, err
	}
	return giftv1.PurchaseGiftReplyFromMoe(resp), nil
}

func (s *AppService) GetGiftRecords(ctx context.Context, in *giftv1.GetGiftRecordsRequest) (*giftv1.GetGiftRecordsReply, error) {
	records, total, err := giftbiz.ListRecords(ctx, s.store, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftRecordsReply{Records: giftv1.GiftRecordsFromMoe(records), Total: total}, nil
}

func (s *AppService) GetGiftPurchaseOrders(ctx context.Context, in *giftv1.GetGiftPurchaseOrdersRequest) (*giftv1.GetGiftPurchaseOrdersReply, error) {
	orders, total, err := giftbiz.ListPurchaseOrders(ctx, s.store, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftPurchaseOrdersReply{Orders: giftv1.GiftPurchaseOrdersFromMoe(orders), Total: total}, nil
}
