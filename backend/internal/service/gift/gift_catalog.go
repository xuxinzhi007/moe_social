package giftapp

import (
	"context"
	giftv1 "backend/api/gift/v1"
	giftbiz "backend/internal/biz/gift"
)

func (s *AppService) GetGifts(ctx context.Context, in *giftv1.GetGiftsRequest) (*giftv1.GetGiftsReply, error) {
	gifts, total, err := giftbiz.ListGifts(ctx, s.store, in.GetPage(), in.GetPageSize(), in.GetViewerUserId())
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftsReply{Gifts: gifts, Total: total}, nil
}

func (s *AppService) GetGift(ctx context.Context, in *giftv1.GetGiftRequest) (*giftv1.GetGiftReply, error) {
	return giftbiz.GetGift(ctx, s.store, in.GetGiftId())
}
