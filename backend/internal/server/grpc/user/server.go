package usergrpc

import (
	"context"

	userv1 "backend/api/user/v1"
	userapp "backend/internal/service/user"
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

func (s *Server) Login(ctx context.Context, in *userv1.LoginReq) (*userv1.LoginResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Login(ctx, in)
}

func (s *Server) Register(ctx context.Context, in *userv1.RegisterReq) (*userv1.RegisterResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Register(ctx, in)
}

func (s *Server) GetUserInfo(ctx context.Context, in *userv1.GetUserInfoReq) (*userv1.GetUserInfoResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserInfo(ctx, in)
}

func (s *Server) GetUser(ctx context.Context, in *userv1.GetUserReq) (*userv1.GetUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUser(ctx, in)
}

func (s *Server) UpdateUserInfo(ctx context.Context, in *userv1.UpdateUserInfoReq) (*userv1.UpdateUserInfoResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateUserInfo(ctx, in)
}
