package userhttp

import (
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
