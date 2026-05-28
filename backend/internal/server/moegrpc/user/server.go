package usergrpc

import (
	"context"

	userv1 "backend/api/user/v1"
	userapp "backend/internal/service/user"
	moerpc "backend/rpc/pb/moe"
)

// Server 实现 user.v1.UserService gRPC（P4-C；与 Super 并存）。
type Server struct {
	userv1.UnimplementedUserServiceServer
	app *userapp.AppService
}

// New 构造 User gRPC 服务。
func New(app *userapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*userapp.AppService, error) {
	if s.app == nil {
		return nil, errUserAppNil
	}
	return s.app, nil
}

func (s *Server) Login(ctx context.Context, in *userv1.LoginRequest) (*userv1.LoginReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.Login(ctx, &moerpc.LoginReq{
		Username: in.GetUsername(), Email: in.GetEmail(), Password: in.GetPassword(),
	})
	if err != nil {
		return nil, err
	}
	return &userv1.LoginReply{User: userToProto(resp.GetUser()), Token: resp.GetToken()}, nil
}

func (s *Server) Register(ctx context.Context, in *userv1.RegisterRequest) (*userv1.RegisterReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.Register(ctx, &moerpc.RegisterReq{
		Username: in.GetUsername(), Password: in.GetPassword(), Email: in.GetEmail(),
	})
	if err != nil {
		return nil, err
	}
	return &userv1.RegisterReply{User: userToProto(resp.GetUser()), Token: resp.GetToken()}, nil
}

func (s *Server) GetUserInfo(ctx context.Context, in *userv1.GetUserInfoRequest) (*userv1.GetUserInfoReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetUserInfo(ctx, &moerpc.GetUserInfoReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &userv1.GetUserInfoReply{User: userToProto(resp.GetUser())}, nil
}

func (s *Server) GetUser(ctx context.Context, in *userv1.GetUserRequest) (*userv1.GetUserReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetUser(ctx, &moerpc.GetUserReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &userv1.GetUserReply{User: userToProto(resp.GetUser())}, nil
}

func (s *Server) UpdateUserInfo(ctx context.Context, in *userv1.UpdateUserInfoRequest) (*userv1.UpdateUserInfoReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.UpdateUserInfo(ctx, &moerpc.UpdateUserInfoReq{
		UserId: in.GetUserId(), Username: in.GetUsername(), Email: in.GetEmail(),
		Avatar: in.GetAvatar(), Signature: in.GetSignature(), Gender: in.GetGender(),
		Birthday: in.GetBirthday(), Inventory: in.GetInventory(),
		EquippedFrameId: in.GetEquippedFrameId(), ClearEquippedFrame: in.GetClearEquippedFrame(),
		MessageRetention: in.GetMessageRetention(),
	})
	if err != nil {
		return nil, err
	}
	return &userv1.UpdateUserInfoReply{User: userToProto(resp.GetUser())}, nil
}
