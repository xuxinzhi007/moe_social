// Package giftapp 礼物域应用服务。
package giftapp

import (
	"context"

	giftbiz "backend/internal/biz/gift"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// AppService 礼物应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

func (s *AppService) GetGifts(ctx context.Context, in *super.GetGiftsReq) (*super.GetGiftsResp, error) {
	gifts, total, err := giftbiz.ListGifts(ctx, s.db, in.GetPage(), in.GetPageSize(), in.GetViewerUserId())
	if err != nil {
		return nil, err
	}
	return &super.GetGiftsResp{Gifts: gifts, Total: total}, nil
}

func (s *AppService) GetGift(ctx context.Context, in *super.GetGiftReq) (*super.GetGiftResp, error) {
	return giftbiz.GetGift(ctx, s.db, in.GetGiftId())
}

func (s *AppService) SendGift(ctx context.Context, in *super.SendGiftReq) (*super.SendGiftResp, error) {
	return giftbiz.Send(ctx, s.db, in.GetFromUserId(), in.GetToUserId(), in.GetGiftId(), in.GetQuantity())
}

func (s *AppService) PurchaseGift(ctx context.Context, in *super.PurchaseGiftReq) (*super.PurchaseGiftResp, error) {
	return giftbiz.Purchase(ctx, s.db, in.GetUserId(), in.GetGiftId(), in.GetQuantity())
}

func (s *AppService) GetGiftRecords(ctx context.Context, in *super.GetGiftRecordsReq) (*super.GetGiftRecordsResp, error) {
	records, total, err := giftbiz.ListRecords(ctx, s.db, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &super.GetGiftRecordsResp{Records: records, Total: total}, nil
}

func (s *AppService) GetGiftPurchaseOrders(ctx context.Context, in *super.GetGiftPurchaseOrdersReq) (*super.GetGiftPurchaseOrdersResp, error) {
	orders, total, err := giftbiz.ListPurchaseOrders(ctx, s.db, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &super.GetGiftPurchaseOrdersResp{Orders: orders, Total: total}, nil
}
