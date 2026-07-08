package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListLevelConfigs(ctx context.Context, in *adminv1.AdminListLevelConfigsReq) (*adminv1.AdminListLevelConfigsResp, error) {
	out, err := adminbiz.ListLevelConfigs(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateLevelConfig(ctx context.Context, in *adminv1.AdminUpdateLevelConfigReq) (*adminv1.AdminUpdateLevelConfigResp, error) {
	out, err := adminbiz.UpdateLevelConfig(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) BootstrapLevels(ctx context.Context, in *adminv1.AdminBootstrapLevelsReq) (*adminv1.AdminBootstrapLevelsResp, error) {
	out, err := adminbiz.BootstrapLevels(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
