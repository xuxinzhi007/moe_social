package vipgrpc

import (
	"context"

	vipv1 "backend/api/vip/v1"
	userapp "backend/internal/service/user"
	moerpc "backend/rpc/pb/moe"
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

func (s *Server) GetVipRecords(ctx context.Context, in *vipv1.GetVipRecordsRequest) (*vipv1.GetVipRecordsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetVipRecords(ctx, &moerpc.GetVipRecordsReq{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return &vipv1.GetVipRecordsReply{
		Records: vipRecordsToProto(resp.GetRecords()), Total: resp.GetTotal(),
	}, nil
}

func (s *Server) GetUserActiveVipRecord(ctx context.Context, in *vipv1.GetUserActiveVipRecordRequest) (*vipv1.GetUserActiveVipRecordReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetUserActiveVipRecord(ctx, &moerpc.GetUserActiveVipRecordReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &vipv1.GetUserActiveVipRecordReply{Record: vipRecordToProto(resp.GetRecord())}, nil
}

func (s *Server) CreateVipOrder(ctx context.Context, in *vipv1.CreateVipOrderRequest) (*vipv1.CreateVipOrderReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.CreateVipOrder(ctx, &moerpc.CreateVipOrderReq{
		UserId: in.GetUserId(), PlanId: in.GetPlanId(),
	})
	if err != nil {
		return nil, err
	}
	out := &vipv1.CreateVipOrderReply{}
	if o := resp.GetOrder(); o != nil {
		out.Success = true
		out.OrderNo = o.GetOrderNo()
	}
	return out, nil
}
