package communitygrpc

import (
	"context"

	communityv1 "backend/api/community/v1"
	communityapp "backend/internal/service/community"
	moerpc "backend/rpc/pb/moe"
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
	resp, err := app.GetGroups(ctx, &moerpc.GetGroupsReq{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(),
		IsPublic: in.GetIsPublic(), UserId: in.GetUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &communityv1.GetGroupsReply{Groups: groupsToProto(resp.GetGroups()), Total: resp.GetTotal()}, nil
}

func (s *Server) GetGroup(ctx context.Context, in *communityv1.GetGroupRequest) (*communityv1.GetGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetGroup(ctx, &moerpc.GetGroupReq{
		GroupId: in.GetGroupId(), UserId: in.GetUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &communityv1.GetGroupReply{
		Success: resp.GetSuccess(), Message: resp.GetMessage(), Group: groupToProto(resp.GetGroup()),
	}, nil
}

func (s *Server) CreateGroup(ctx context.Context, in *communityv1.CreateGroupRequest) (*communityv1.CreateGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.CreateGroup(ctx, &moerpc.CreateGroupReq{
		Name: in.GetName(), Description: in.GetDescription(), Avatar: in.GetAvatar(),
		Cover: in.GetCover(), UserId: in.GetUserId(), IsPublic: in.GetIsPublic(),
	})
	if err != nil {
		return nil, err
	}
	return &communityv1.CreateGroupReply{
		Success: resp.GetSuccess(), Message: resp.GetMessage(), Group: groupToProto(resp.GetGroup()),
	}, nil
}

func (s *Server) JoinGroup(ctx context.Context, in *communityv1.JoinGroupRequest) (*communityv1.JoinGroupReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.JoinGroup(ctx, &moerpc.JoinGroupReq{
		GroupId: in.GetGroupId(), UserId: in.GetUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &communityv1.JoinGroupReply{Success: resp.GetSuccess(), Message: resp.GetMessage()}, nil
}
