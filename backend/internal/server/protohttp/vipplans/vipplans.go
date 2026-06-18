package vipplanshttp

import (
	"context"

	vipv1 "backend/api/vip/v1"
	vipbiz "backend/internal/biz/vip"
	vipadmin "backend/internal/service/vip"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errVipAdminNil = status.Error(codes.FailedPrecondition, "VipAdmin 未初始化")

// Server 实现 vip.v1.VipPlans gRPC/HTTP（公开套餐 CRUD）。
type Server struct {
	vipv1.UnimplementedVipPlansServer
	admin *vipadmin.AdminService
}

// New 构造 VipPlans gRPC/HTTP 服务。
func New(admin *vipadmin.AdminService) *Server {
	return &Server{admin: admin}
}

func (s *Server) requireAdmin() (*vipadmin.AdminService, error) {
	if s.admin == nil {
		return nil, errVipAdminNil
	}
	return s.admin, nil
}

func (s *Server) CreateVipPlan(ctx context.Context, in *vipv1.CreateVipPlanReq) (*vipv1.CreateVipPlanResp, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	plan, err := admin.CreatePlan(ctx, vipbiz.CreatePlanInput{
		Name:         in.GetName(),
		Description:  in.GetDescription(),
		Price:        float64(in.GetPrice()),
		DurationDays: int(in.GetDurationDays()),
	})
	if err != nil {
		return nil, err
	}
	return &vipv1.CreateVipPlanResp{Plan: vipbiz.PlanModelToVipProto(plan)}, nil
}

func (s *Server) GetVipPlan(ctx context.Context, in *vipv1.GetVipPlanReq) (*vipv1.GetVipPlanResp, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	planID, err := vipbiz.ParsePlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	plan, err := admin.GetPlan(ctx, planID)
	if err != nil {
		return nil, err
	}
	return &vipv1.GetVipPlanResp{Plan: vipbiz.PlanModelToVipProto(plan)}, nil
}

func (s *Server) GetVipPlans(ctx context.Context, _ *vipv1.GetVipPlansReq) (*vipv1.GetVipPlansResp, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	rows, err := admin.ListAllPlans(ctx)
	if err != nil {
		return nil, err
	}
	plans := make([]*vipv1.VipPlan, 0, len(rows))
	for i := range rows {
		plans = append(plans, vipbiz.PlanModelToVipProto(rows[i]))
	}
	return &vipv1.GetVipPlansResp{Plans: plans}, nil
}
