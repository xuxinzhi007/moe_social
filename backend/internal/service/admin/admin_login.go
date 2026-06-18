package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

// AdminLogin 管理端登录。
func (s *AppService) AdminLogin(ctx context.Context, in *adminv1.AdminLoginReq) (*adminv1.AdminLoginResp, error) {
	out, err := adminbiz.AdminLogin(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// AdminBootstrapAccount 引导默认超管。
func (s *AppService) AdminBootstrapAccount(ctx context.Context, in *adminv1.AdminBootstrapAccountReq) (*adminv1.AdminBootstrapAccountResp, error) {
	out, err := adminbiz.BootstrapAdminAccount(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
