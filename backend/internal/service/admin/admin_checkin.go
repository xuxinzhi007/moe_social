package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListCheckInRewards(ctx context.Context, in *adminv1.AdminListCheckInRewardsReq) (*adminv1.AdminListCheckInRewardsResp, error) {
	out, err := adminbiz.ListCheckInRewards(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateCheckInReward(ctx context.Context, in *adminv1.AdminUpdateCheckInRewardReq) (*adminv1.AdminUpdateCheckInRewardResp, error) {
	out, err := adminbiz.UpdateCheckInReward(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
