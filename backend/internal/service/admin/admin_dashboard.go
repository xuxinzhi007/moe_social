package adminapp

import (
	"context"
	"backend/utils"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

// GrowthStats 成长统计。
func (s *AppService) GrowthStats(ctx context.Context) (*adminv1.AdminGetGrowthStatsResp, error) {
	stats, err := adminbiz.GrowthStats(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return adminbiz.GrowthStatsV1(stats), nil
}

// SchemaCatalog 数据目录。
func (s *AppService) SchemaCatalog(ctx context.Context) (*adminv1.AdminGetSchemaCatalogResp, error) {
	out, err := adminbiz.SchemaCatalog(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// ReadRuntimeConfig 运行时配置视图。
func (s *AppService) ReadRuntimeConfig() (utils.RuntimeConfigView, error) {
	return adminbiz.RuntimeConfigView()
}

// RuntimeOverview 进程内存与布局汇总。
func (s *AppService) RuntimeOverview(ctx context.Context) (*adminbiz.RuntimeOverviewResult, error) {
	return adminbiz.RuntimeOverview(ctx)
}

func (s *AppService) AnalyticsOverview(ctx context.Context, in *adminv1.AdminGetMemoryStatsReq) (*adminv1.AdminAnalyticsOverviewResp, error) {
	out, err := adminbiz.AdminAnalyticsOverview(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) Dashboard(ctx context.Context, in *adminv1.AdminDashboardReq) (*adminv1.AdminDashboardResp, error) {
	out, err := adminbiz.Dashboard(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
