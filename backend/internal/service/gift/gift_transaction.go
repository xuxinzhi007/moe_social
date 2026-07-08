package giftapp

import (
	"context"
	giftv1 "backend/api/gift/v1"
	giftbiz "backend/internal/biz/gift"
)

func (s *AppService) SendGift(ctx context.Context, in *giftv1.SendGiftRequest) (*giftv1.SendGiftReply, error) {
	return giftbiz.Send(ctx, s.store, s.notify, in.GetFromUserId(), in.GetToUserId(), in.GetGiftId(), in.GetQuantity())
}

func (s *AppService) PurchaseGift(ctx context.Context, in *giftv1.PurchaseGiftRequest) (*giftv1.PurchaseGiftReply, error) {
	return giftbiz.Purchase(ctx, s.store, in.GetUserId(), in.GetGiftId(), in.GetQuantity())
}

func (s *AppService) GetGiftRecords(ctx context.Context, in *giftv1.GetGiftRecordsRequest) (*giftv1.GetGiftRecordsReply, error) {
	records, total, err := giftbiz.ListRecords(ctx, s.store, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftRecordsReply{Records: records, Total: total}, nil
}

func (s *AppService) GetGiftPurchaseOrders(ctx context.Context, in *giftv1.GetGiftPurchaseOrdersRequest) (*giftv1.GetGiftPurchaseOrdersReply, error) {
	orders, total, err := giftbiz.ListPurchaseOrders(ctx, s.store, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftPurchaseOrdersReply{Orders: orders, Total: total}, nil
}
