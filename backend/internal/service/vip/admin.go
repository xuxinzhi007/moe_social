// Package vipadmin VIP 管理端应用服务（Hybrid：API in_process / RPC 可复用 biz）。
package vipadmin

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/model"

	"gorm.io/gorm"
)

// AdminService VIP 套餐管理。
type AdminService struct {
	db *gorm.DB
}

// NewAdmin 构造 AdminService。
func NewAdmin(db *gorm.DB) *AdminService {
	return &AdminService{db: db}
}

// ListPlans 分页列表。
func (s *AdminService) ListPlans(ctx context.Context, f vipbiz.ListPlansFilter) ([]model.VipPlan, int64, error) {
	return vipbiz.ListPlans(ctx, s.db, f)
}

// ListAllPlans 全量列表（公开 API）。
func (s *AdminService) ListAllPlans(ctx context.Context) ([]model.VipPlan, error) {
	return vipbiz.ListAllPlans(ctx, s.db)
}

// GetPlan 单条查询。
func (s *AdminService) GetPlan(ctx context.Context, planID uint) (model.VipPlan, error) {
	return vipbiz.GetPlan(ctx, s.db, planID)
}

// CreatePlan 创建。
func (s *AdminService) CreatePlan(ctx context.Context, in vipbiz.CreatePlanInput) (model.VipPlan, error) {
	return vipbiz.CreatePlan(ctx, s.db, in)
}

// UpdatePlan 更新。
func (s *AdminService) UpdatePlan(ctx context.Context, planID uint, patch vipbiz.UpdatePlanPatch) (model.VipPlan, error) {
	return vipbiz.UpdatePlan(ctx, s.db, planID, patch)
}

// DeletePlan 删除。
func (s *AdminService) DeletePlan(ctx context.Context, planID uint) error {
	return vipbiz.DeletePlan(ctx, s.db, planID)
}

// BootstrapPlans 初始化默认套餐。
func (s *AdminService) BootstrapPlans(ctx context.Context) (int, error) {
	return vipbiz.BootstrapPlans(ctx, s.db)
}
