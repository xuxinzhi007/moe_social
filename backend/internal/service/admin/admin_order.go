package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListVipOrders(ctx context.Context, in *adminv1.AdminListVipOrdersReq) (*adminv1.AdminListVipOrdersResp, error) {
	out, err := adminbiz.ListVipOrders(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListGiftPurchaseOrders(ctx context.Context, in *adminv1.AdminListGiftPurchaseOrdersReq) (*adminv1.AdminListGiftPurchaseOrdersResp, error) {
	out, err := adminbiz.ListGiftPurchaseOrders(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
