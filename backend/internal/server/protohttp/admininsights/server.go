package admininsightshttp

import (
	"context"

	adminv1 "backend/api/admin/v1"
	adminapp "backend/internal/service/admin"
)

// Server 实现 admin.v1.AdminInsights HTTP/gRPC 适配（D2 试点）。
type Server struct {
	adminv1.UnimplementedAdminInsightsServer
	app *adminapp.AppService
}

// New 构造 AdminInsights 服务。
func New(app *adminapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*adminapp.AppService, error) {
	if s.app == nil {
		return nil, errAdminAppNil
	}
	return s.app, nil
}

func (s *Server) AdminListAiChatSessions(ctx context.Context, in *adminv1.AdminListAiChatSessionsReq) (*adminv1.AdminListAiChatSessionsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAiChatSessions(ctx, in)
}

func (s *Server) AdminListAiChatMessages(ctx context.Context, in *adminv1.AdminListAiChatMessagesReq) (*adminv1.AdminListAiChatMessagesResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAiChatMessages(ctx, in)
}

func (s *Server) AdminExportAiChatMessages(ctx context.Context, in *adminv1.AdminExportAiChatMessagesReq) (*adminv1.AdminExportAiChatMessagesResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ExportAiChatMessages(ctx, in)
}

func (s *Server) AdminAnalyticsOverview(ctx context.Context, in *adminv1.AdminGetMemoryStatsReq) (*adminv1.AdminAnalyticsOverviewResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AnalyticsOverview(ctx, in)
}

func (s *Server) AdminListTopicTags(ctx context.Context, in *adminv1.AdminListTopicTagsReq) (*adminv1.AdminListTopicTagsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListTopicTags(ctx, in)
}

func (s *Server) AdminDashboard(ctx context.Context, in *adminv1.AdminDashboardReq) (*adminv1.AdminDashboardResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Dashboard(ctx, in)
}

func (s *Server) AdminGrowthStats(ctx context.Context, in *adminv1.AdminGetGrowthStatsReq) (*adminv1.AdminGetGrowthStatsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	_ = in
	return app.GrowthStats(ctx)
}

func (s *Server) AdminSchemaCatalog(ctx context.Context, in *adminv1.AdminGetSchemaCatalogReq) (*adminv1.AdminGetSchemaCatalogResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	_ = in
	return app.SchemaCatalog(ctx)
}
