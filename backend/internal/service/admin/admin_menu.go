package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListMenus(ctx context.Context, in *adminv1.AdminListMenusReq) (*adminv1.AdminListMenusResp, error) {
	_ = in
	items, err := adminbiz.ListMenus(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return adminbiz.ListMenusV1(items), nil
}

func (s *AppService) UpsertMenu(ctx context.Context, in *adminv1.AdminUpsertMenuReq) (*adminv1.AdminUpsertMenuResp, error) {
	item, err := adminbiz.UpsertMenu(ctx, s.store, adminbiz.UpsertMenuInput{
		Key: in.GetKey(), Kind: in.GetKind(), ParentKey: in.GetParentKey(), Path: in.GetPath(),
		Label: in.GetLabel(), Icon: in.GetIcon(), Caption: in.GetCaption(), Status: in.GetStatus(),
		AppDomain: in.GetAppDomain(), SortOrder: in.GetSortOrder(), DefaultOpen: in.GetDefaultOpen(),
		End: in.GetEnd(), ExternalHref: in.GetExternalHref(), Enabled: in.GetEnabled(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.UpsertMenuV1(item), nil
}

func (s *AppService) DeleteMenu(ctx context.Context, in *adminv1.AdminDeleteMenuReq) (*adminv1.AdminDeleteMenuResp, error) {
	if err := adminbiz.DeleteMenu(ctx, s.store, in.GetMenuKey()); err != nil {
		return nil, err
	}
	return &adminv1.AdminDeleteMenuResp{}, nil
}

func (s *AppService) BootstrapMenus(ctx context.Context, in *adminv1.AdminBootstrapMenusReq) (*adminv1.AdminBootstrapMenusResp, error) {
	_ = in
	created, err := adminbiz.BootstrapMenus(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapMenusResp{Created: created}, nil
}
