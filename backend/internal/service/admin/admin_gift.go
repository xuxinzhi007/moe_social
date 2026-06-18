package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) AdminListGifts(ctx context.Context, in *adminv1.AdminListGiftsReq) (*adminv1.AdminListGiftsResp, error) {
	gifts, total, err := adminbiz.ListGifts(ctx, s.db, adminbiz.GiftPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(),
		Keyword: in.GetKeyword(), Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListGiftsV1(gifts, total), nil
}

func (s *AppService) AdminGetGift(ctx context.Context, in *adminv1.AdminGetGiftReq) (*adminv1.AdminGetGiftResp, error) {
	gift, err := adminbiz.GetGift(ctx, s.db, in.GetGiftId())
	if err != nil {
		return nil, err
	}
	return adminbiz.GiftV1(gift), nil
}

func (s *AppService) AdminCreateGift(ctx context.Context, in *adminv1.AdminCreateGiftReq) (*adminv1.AdminCreateGiftResp, error) {
	gift, err := adminbiz.CreateGift(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return adminbiz.CreateGiftV1(gift), nil
}

func (s *AppService) AdminUpdateGift(ctx context.Context, in *adminv1.AdminUpdateGiftReq) (*adminv1.AdminUpdateGiftResp, error) {
	gift, err := adminbiz.UpdateGift(ctx, s.db, adminbiz.UpdateGiftInput{
		GiftIDRaw:         in.GetGiftId(),
		Name:              in.GetName(),
		Price:             in.GetPrice(),
		Icon:              in.GetIcon(),
		Description:       in.GetDescription(),
		Category:          in.GetCategory(),
		SortOrder:         in.GetSortOrder(),
		UpdateName:        in.GetUpdateName(),
		UpdatePrice:       in.GetUpdatePrice(),
		UpdateIcon:        in.GetUpdateIcon(),
		UpdateDescription: in.GetUpdateDescription(),
		UpdateCategory:    in.GetUpdateCategory(),
		UpdateSortOrder:   in.GetUpdateSortOrder(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.UpdateGiftV1(gift), nil
}

func (s *AppService) AdminDeleteGift(ctx context.Context, in *adminv1.AdminDeleteGiftReq) (*adminv1.AdminDeleteGiftResp, error) {
	if err := adminbiz.DeleteGift(ctx, s.db, in.GetGiftId()); err != nil {
		return nil, err
	}
	return &adminv1.AdminDeleteGiftResp{}, nil
}

func (s *AppService) AdminBootstrapGifts(ctx context.Context, in *adminv1.AdminBootstrapGiftsReq) (*adminv1.AdminBootstrapGiftsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapGifts(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapGiftsResp{Created: created}, nil
}

func (s *AppService) AdminDedupeGifts(ctx context.Context, in *adminv1.AdminDedupeGiftsReq) (*adminv1.AdminDedupeGiftsResp, error) {
	_ = in
	removed, err := adminbiz.DeduplicateGiftsByName(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminDedupeGiftsResp{Removed: removed}, nil
}
