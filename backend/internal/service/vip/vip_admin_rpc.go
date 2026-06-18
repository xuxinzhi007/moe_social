package vipadmin

import (
	"context"
	adminv1 "backend/api/admin/v1"
	vipbiz "backend/internal/biz/vip"
)

// AdminListVipPlans RPC/管理端列表。
func (s *AdminService) AdminListVipPlans(ctx context.Context, in *adminv1.AdminListVipPlansReq) (*adminv1.AdminListVipPlansResp, error) {
	rows, total, err := s.ListPlans(ctx, vipbiz.ListPlansFilter{
		Page:           int(in.GetPage()),
		PageSize:       int(in.GetPageSize()),
		Keyword:        in.GetKeyword(),
		IncludeDeleted: in.GetIncludeDeleted(),
	})
	if err != nil {
		return nil, err
	}
	plans := make([]*adminv1.VipPlan, len(rows))
	for i := range rows {
		plans[i] = vipbiz.PlanModelToAdminProto(rows[i])
	}
	return &adminv1.AdminListVipPlansResp{Plans: plans, Total: int32(total)}, nil
}

// AdminGetVipPlan 单条套餐。
func (s *AdminService) AdminGetVipPlan(ctx context.Context, in *adminv1.AdminGetVipPlanReq) (*adminv1.AdminGetVipPlanResp, error) {
	id, err := vipbiz.ParsePlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminGetVipPlanResp{Plan: vipbiz.PlanModelToAdminProto(plan)}, nil
}

// AdminUpdateVipPlan 更新套餐。
func (s *AdminService) AdminUpdateVipPlan(ctx context.Context, in *adminv1.AdminUpdateVipPlanReq) (*adminv1.AdminUpdateVipPlanResp, error) {
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
	return &adminv1.AdminUpdateVipPlanResp{Plan: vipbiz.PlanModelToAdminProto(plan)}, nil
}

// AdminDeleteVipPlan 删除套餐。
func (s *AdminService) AdminDeleteVipPlan(ctx context.Context, in *adminv1.AdminDeleteVipPlanReq) (*adminv1.AdminDeleteVipPlanResp, error) {
	planID, err := vipbiz.ParsePlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	if err := s.DeletePlan(ctx, planID); err != nil {
		return nil, err
	}
	return &adminv1.AdminDeleteVipPlanResp{}, nil
}

// AdminBootstrapVipPlans 初始化默认套餐。
func (s *AdminService) AdminBootstrapVipPlans(ctx context.Context, in *adminv1.AdminBootstrapVipPlansReq) (*adminv1.AdminBootstrapVipPlansResp, error) {
	_ = in
	created, err := s.BootstrapPlans(ctx)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapVipPlansResp{Created: int32(created)}, nil
}
