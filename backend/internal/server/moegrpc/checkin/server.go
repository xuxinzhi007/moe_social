package checkingrpc

import (
	"context"

	checkinv1 "backend/api/checkin/v1"
	checkinapp "backend/internal/service/checkin"
)

// Server 实现 checkin.v1.Checkin gRPC（P4-C；与 Super 并存）。
type Server struct {
	checkinv1.UnimplementedCheckinServer
	app *checkinapp.AppService
}

// New 构造 Checkin gRPC 服务。
func New(app *checkinapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*checkinapp.AppService, error) {
	if s.app == nil {
		return nil, errCheckinAppNil
	}
	return s.app, nil
}

func (s *Server) CheckIn(ctx context.Context, in *checkinv1.CheckInRequest) (*checkinv1.CheckInReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CheckIn(ctx, in)
}

func (s *Server) GetUserLevel(ctx context.Context, in *checkinv1.GetUserLevelRequest) (*checkinv1.GetUserLevelReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserLevel(ctx, in)
}

func (s *Server) GetCheckInStatus(ctx context.Context, in *checkinv1.GetCheckInStatusRequest) (*checkinv1.GetCheckInStatusReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetCheckInStatus(ctx, in)
}

func (s *Server) GetCheckInHistory(ctx context.Context, in *checkinv1.GetCheckInHistoryRequest) (*checkinv1.GetCheckInHistoryReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetCheckInHistory(ctx, in)
}

func (s *Server) GetExpLogs(ctx context.Context, in *checkinv1.GetExpLogsRequest) (*checkinv1.GetExpLogsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetExpLogs(ctx, in)
}
