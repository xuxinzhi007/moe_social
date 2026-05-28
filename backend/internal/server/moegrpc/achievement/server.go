package achievementgrpc

import (
	"context"

	achievementv1 "backend/api/achievement/v1"
	achievementapp "backend/internal/service/achievement"
	moerpc "backend/rpc/pb/moe"
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
	resp, err := app.GetUserAchievements(ctx, &moerpc.GetUserAchievementsReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &achievementv1.GetUserAchievementsReply{Badges: badgesToProto(resp.GetBadges())}, nil
}

func (s *Server) GetUserUnlockedAchievements(ctx context.Context, in *achievementv1.GetUserUnlockedAchievementsRequest) (*achievementv1.GetUserUnlockedAchievementsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetUserUnlockedAchievements(ctx, &moerpc.GetUserUnlockedAchievementsReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &achievementv1.GetUserUnlockedAchievementsReply{Badges: badgesToProto(resp.GetBadges())}, nil
}

func (s *Server) GetUserAchievementSummary(ctx context.Context, in *achievementv1.GetUserAchievementSummaryRequest) (*achievementv1.GetUserAchievementSummaryReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetUserAchievementSummary(ctx, &moerpc.GetUserAchievementSummaryReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &achievementv1.GetUserAchievementSummaryReply{Summary: summaryToProto(resp.GetSummary())}, nil
}

func (s *Server) EnsureUserAchievements(ctx context.Context, in *achievementv1.EnsureUserAchievementsRequest) (*achievementv1.EnsureUserAchievementsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.EnsureUserAchievements(ctx, &moerpc.EnsureUserAchievementsReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &achievementv1.EnsureUserAchievementsReply{
		NewAchievements: achievementUnlocksToProto(resp.GetNewAchievements()),
	}, nil
}
