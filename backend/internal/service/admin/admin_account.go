package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListAccounts(ctx context.Context, in *adminv1.AdminListAccountsReq) (*adminv1.AdminListAccountsResp, error) {
	out, err := adminbiz.ListAccounts(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) CreateAccount(ctx context.Context, in *adminv1.AdminCreateAccountReq) (*adminv1.AdminCreateAccountResp, error) {
	out, err := adminbiz.CreateAccount(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateAccount(ctx context.Context, in *adminv1.AdminUpdateAccountReq) (*adminv1.AdminUpdateAccountResp, error) {
	out, err := adminbiz.UpdateAccount(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteAccount(ctx context.Context, in *adminv1.AdminDeleteAccountReq) (*adminv1.AdminDeleteAccountResp, error) {
	out, err := adminbiz.DeleteAccount(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
