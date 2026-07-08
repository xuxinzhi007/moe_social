package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListAchievements(ctx context.Context, in *adminv1.AdminListAchievementsReq) (*adminv1.AdminListAchievementsResp, error) {
	items, total, err := adminbiz.ListAchievements(ctx, s.store, adminbiz.AchievementPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(),
		Keyword: in.GetKeyword(), Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListAchievementsV1(items, total), nil
}

func (s *AppService) UpdateAchievement(ctx context.Context, in *adminv1.AdminUpdateAchievementReq) (*adminv1.AdminUpdateAchievementResp, error) {
	item, err := adminbiz.UpdateAchievement(ctx, s.store, adminbiz.UpdateAchievementInput{
		ID: in.GetId(), Name: in.GetName(), Description: in.GetDescription(),
		Enabled: in.GetEnabled(), ExpReward: in.GetExpReward(), SortOrder: in.GetSortOrder(),
		UpdateName: in.GetUpdateName(), UpdateDescription: in.GetUpdateDescription(),
		UpdateEnabled: in.GetUpdateEnabled(), UpdateExpReward: in.GetUpdateExpReward(),
		UpdateSortOrder: in.GetUpdateSortOrder(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.UpdateAchievementV1(item), nil
}

func (s *AppService) BootstrapAchievements(ctx context.Context, in *adminv1.AdminBootstrapAchievementsReq) (*adminv1.AdminBootstrapAchievementsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapAchievements(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapAchievementsResp{Created: created}, nil
}
