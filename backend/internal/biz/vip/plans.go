// Package vipbiz VIP 域业务（Phase 5 纯 Kratos 试点，只读）。
package vipbiz

import (
	"context"
	"strings"

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
func ListPlans(ctx context.Context, db *gorm.DB, f ListPlansFilter) ([]model.VipPlan, int64, error) {
	if db == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page := f.Page
	if page <= 0 {
		page = 1
	}
	pageSize := f.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := db.WithContext(ctx).Model(&model.VipPlan{})
	if f.IncludeDeleted {
		q = q.Unscoped()
	}
	if kw := strings.TrimSpace(f.Keyword); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR features LIKE ?", like, like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var rows []model.VipPlan
	offset := (page - 1) * pageSize
	if err := q.Order("id ASC").Offset(offset).Limit(pageSize).Find(&rows).Error; err != nil {
		return nil, 0, err
	}
	return rows, total, nil
}
