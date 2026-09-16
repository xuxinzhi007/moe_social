package adminapp

import (
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
	"context"
)

// AdminLogin 管理端登录。
func (s *AppService) AdminLogin(ctx context.Context, in *adminv1.AdminLoginReq) (*adminv1.AdminLoginResp, error) {
	out, err := adminbiz.AdminLogin(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
