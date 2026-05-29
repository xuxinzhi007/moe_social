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

func (s *Server) UpdateGroup(ctx context.Context, in *communityv1.UpdateGroupRequest) (*communityv1.UpdateGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateGroup(ctx, in)
}

func (s *Server) DeleteGroup(ctx context.Context, in *communityv1.DeleteGroupRequest) (*communityv1.DeleteGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteGroup(ctx, in)
}

func (s *Server) LeaveGroup(ctx context.Context, in *communityv1.LeaveGroupRequest) (*communityv1.LeaveGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.LeaveGroup(ctx, in)
}

func (s *Server) GetGroupMembers(ctx context.Context, in *communityv1.GetGroupMembersRequest) (*communityv1.GetGroupMembersReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGroupMembers(ctx, in)
}

func (s *Server) GetUserGroups(ctx context.Context, in *communityv1.GetUserGroupsRequest) (*communityv1.GetUserGroupsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserGroups(ctx, in)
}

func (s *Server) CreateGroupPost(ctx context.Context, in *communityv1.CreateGroupPostRequest) (*communityv1.CreateGroupPostReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CreateGroupPost(ctx, in)
}

func (s *Server) GetGroupPosts(ctx context.Context, in *communityv1.GetGroupPostsRequest) (*communityv1.GetGroupPostsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGroupPosts(ctx, in)
}
