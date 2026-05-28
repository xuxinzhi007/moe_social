package vipgrpc

import (
	"context"

	vipv1 "backend/api/vip/v1"
	userapp "backend/internal/service/user"
)

// Server 实现 vip.v1.VipService gRPC（P4-C；UserApp 委托；与 Super 并存）。
type Server struct {
	vipv1.UnimplementedVipServiceServer
	app *userapp.AppService
}

// New 构造 Vip gRPC 服务。
func New(app *userapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*userapp.AppService, error) {
	if s.app == nil {
		return nil, errVipAppNil
	}
	return s.app, nil
}

func (s *Server) GetVipRecords(ctx context.Context, in *vipv1.GetVipRecordsReq) (*vipv1.GetVipRecordsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetVipRecords(ctx, in)
}

func (s *Server) GetUserActiveVipRecord(ctx context.Context, in *vipv1.GetUserActiveVipRecordReq) (*vipv1.GetUserActiveVipRecordResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserActiveVipRecord(ctx, in)
}

func (s *Server) CreateVipOrder(ctx context.Context, in *vipv1.CreateVipOrderReq) (*vipv1.CreateVipOrderResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CreateVipOrder(ctx, in)
}
