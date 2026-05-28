package vipadmin

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/pb/moe"
)

// AdminListVipPlans RPC/管理端列表。
func (s *AdminService) AdminListVipPlans(ctx context.Context, in *moe.AdminListVipPlansReq) (*moe.AdminListVipPlansResp, error) {
	rows, total, err := s.ListPlans(ctx, vipbiz.ListPlansFilter{
		Page:           int(in.GetPage()),
		PageSize:       int(in.GetPageSize()),
		Keyword:        in.GetKeyword(),
		IncludeDeleted: in.GetIncludeDeleted(),
	})
	if err != nil {
		return nil, err
	}
	plans := make([]*moe.VipPlan, len(rows))
	for i := range rows {
		plans[i] = vipbiz.PlanModelToProto(rows[i])
	}
	return &moe.AdminListVipPlansResp{Plans: plans, Total: int32(total)}, nil
}

// AdminGetVipPlan 单条套餐。
func (s *AdminService) AdminGetVipPlan(ctx context.Context, in *moe.AdminGetVipPlanReq) (*moe.AdminGetVipPlanResp, error) {
	id, err := vipbiz.ParsePlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return nil, err
	}
	return &moe.AdminGetVipPlanResp{Plan: vipbiz.PlanModelToProto(plan)}, nil
}

// AdminUpdateVipPlan 更新套餐。
func (s *AdminService) AdminUpdateVipPlan(ctx context.Context, in *moe.AdminUpdateVipPlanReq) (*moe.AdminUpdateVipPlanResp, error) {
	planID, err := vipbiz.ParsePlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	plan, err := s.UpdatePlan(ctx, planID, vipbiz.UpdatePlanPatch{
		UpdateName:         in.GetUpdateName(),
		Name:               in.GetName(),
		UpdateDescription:  in.GetUpdateDescription(),
		Description:        in.GetDescription(),
		UpdatePrice:        in.GetUpdatePrice(),
		Price:              float64(in.GetPrice()),
		UpdateDurationDays: in.GetUpdateDurationDays(),
		DurationDays:       int(in.GetDurationDays()),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminUpdateVipPlanResp{Plan: vipbiz.PlanModelToProto(plan)}, nil
}

// AdminDeleteVipPlan 删除套餐。
func (s *AdminService) AdminDeleteVipPlan(ctx context.Context, in *moe.AdminDeleteVipPlanReq) (*moe.AdminDeleteVipPlanResp, error) {
	planID, err := vipbiz.ParsePlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	if err := s.DeletePlan(ctx, planID); err != nil {
		return nil, err
	}
	return &moe.AdminDeleteVipPlanResp{}, nil
}

// AdminBootstrapVipPlans 初始化默认套餐。
func (s *AdminService) AdminBootstrapVipPlans(ctx context.Context, in *moe.AdminBootstrapVipPlansReq) (*moe.AdminBootstrapVipPlansResp, error) {
	_ = in
	created, err := s.BootstrapPlans(ctx)
	if err != nil {
		return nil, err
	}
	return &moe.AdminBootstrapVipPlansResp{Created: int32(created)}, nil
}
