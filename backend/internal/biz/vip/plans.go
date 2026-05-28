// Package vipbiz VIP 域业务（Phase 5 纯 Kratos 试点，只读）。
package vipbiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// ListPlansFilter 管理台套餐列表筛选。
type ListPlansFilter struct {
	Page           int
	PageSize       int
	Keyword        string
	IncludeDeleted bool
}

// ListPlans 分页查询 VIP 套餐（不经过 super.proto）。
func ListPlans(ctx context.Context, st VipStore, f ListPlansFilter) ([]model.VipPlan, int64, error) {
	if st == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	return st.WithContext(ctx).ListPlans(ctx, f)
}
