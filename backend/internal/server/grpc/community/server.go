package communitygrpc

import (
	"context"

	communityv1 "backend/api/community/v1"
	communityapp "backend/internal/service/community"
)

// Server 实现 community.v1.Community gRPC（P4-C；与 Super 并存）。
type Server struct {
	communityv1.UnimplementedCommunityServer
	app *communityapp.AppService
}

// New 构造 Community gRPC 服务。
func New(app *communityapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*communityapp.AppService, error) {
	if s.app == nil {
		return nil, errCommunityAppNil
	}
	return s.app, nil
}

func (s *Server) GetGroups(ctx context.Context, in *communityv1.GetGroupsRequest) (*communityv1.GetGroupsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGroups(ctx, in)
}

func (s *Server) GetGroup(ctx context.Context, in *communityv1.GetGroupRequest) (*communityv1.GetGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGroup(ctx, in)
}

func (s *Server) CreateGroup(ctx context.Context, in *communityv1.CreateGroupRequest) (*communityv1.CreateGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CreateGroup(ctx, in)
}

func (s *Server) JoinGroup(ctx context.Context, in *communityv1.JoinGroupRequest) (*communityv1.JoinGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.JoinGroup(ctx, in)
}
