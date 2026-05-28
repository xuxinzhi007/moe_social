package vipbiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// VipStore VIP 套餐持久化（P4-D4；默认由 internal/data/vip 实现）。
type VipStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) VipStore

	ListPlans(ctx context.Context, f ListPlansFilter) ([]model.VipPlan, int64, error)
	ListAllPlans(ctx context.Context) ([]model.VipPlan, error)
	GetPlan(ctx context.Context, planID uint) (model.VipPlan, error)
	CreatePlan(ctx context.Context, plan *model.VipPlan) error
	SavePlan(ctx context.Context, plan *model.VipPlan) error
	FindActivePlan(ctx context.Context, planID uint) (model.VipPlan, error)
	DeletePlan(ctx context.Context, planID uint) error
	CountPlans(ctx context.Context) (int64, error)
	CreatePlans(ctx context.Context, plans []model.VipPlan) error
}
