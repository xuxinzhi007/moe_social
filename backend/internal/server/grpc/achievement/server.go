package achievementgrpc

import (
	"context"

	achievementv1 "backend/api/achievement/v1"
	achievementapp "backend/internal/service/achievement"
)

// Server 实现 achievement.v1.Achievement gRPC（P4-C；与 Super 并存）。
type Server struct {
	achievementv1.UnimplementedAchievementServer
	app *achievementapp.AppService
}

// New 构造 Achievement gRPC 服务。
func New(app *achievementapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*achievementapp.AppService, error) {
	if s.app == nil {
		return nil, errAchievementAppNil
	}
	return s.app, nil
}

func (s *Server) GetUserAchievements(ctx context.Context, in *achievementv1.GetUserAchievementsRequest) (*achievementv1.GetUserAchievementsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserAchievements(ctx, in)
}

func (s *Server) GetUserUnlockedAchievements(ctx context.Context, in *achievementv1.GetUserUnlockedAchievementsRequest) (*achievementv1.GetUserUnlockedAchievementsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserUnlockedAchievements(ctx, in)
}

func (s *Server) GetUserAchievementSummary(ctx context.Context, in *achievementv1.GetUserAchievementSummaryRequest) (*achievementv1.GetUserAchievementSummaryReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserAchievementSummary(ctx, in)
}

func (s *Server) EnsureUserAchievements(ctx context.Context, in *achievementv1.EnsureUserAchievementsRequest) (*achievementv1.EnsureUserAchievementsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.EnsureUserAchievements(ctx, in)
}
