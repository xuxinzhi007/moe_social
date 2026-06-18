package viphttp

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

func (s *Server) GetUserVipStatus(ctx context.Context, in *vipv1.GetUserVipStatusReq) (*vipv1.GetUserVipStatusResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserVipStatus(ctx, in)
}

func (s *Server) UpdateUserVip(ctx context.Context, in *vipv1.UpdateUserVipReq) (*vipv1.UpdateUserVipResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateUserVip(ctx, in)
}

func (s *Server) UpdateAutoRenew(ctx context.Context, in *vipv1.UpdateAutoRenewReq) (*vipv1.UpdateAutoRenewResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateAutoRenew(ctx, in)
}

func (s *Server) CheckUserVip(ctx context.Context, in *vipv1.CheckUserVipReq) (*vipv1.CheckUserVipResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CheckUserVip(ctx, in)
}

func (s *Server) GetVipOrders(ctx context.Context, in *vipv1.GetVipOrdersReq) (*vipv1.GetVipOrdersResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetVipOrders(ctx, in)
}

func (s *Server) SyncUserVipStatus(ctx context.Context, in *vipv1.SyncUserVipStatusReq) (*vipv1.SyncUserVipStatusResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.SyncUserVipStatus(ctx, in)
}
