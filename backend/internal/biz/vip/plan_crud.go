package vipbiz

import (
	"context"
	"errors"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// CreatePlanInput 创建套餐。
type CreatePlanInput struct {
	Name         string
	Description  string
	Price        float64
	DurationDays int
}

// UpdatePlanPatch 部分更新套餐。
type UpdatePlanPatch struct {
	UpdateName         bool
	Name               string
	UpdateDescription  bool
	Description        string
	UpdatePrice        bool
	Price              float64
	UpdateDurationDays bool
	DurationDays       int
}

// ListAllPlans 公开列表（未删除）。
func ListAllPlans(ctx context.Context, db *gorm.DB) ([]model.VipPlan, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	var rows []model.VipPlan
	if err := db.WithContext(ctx).Order("id ASC").Find(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}

// GetPlan 按 ID 查询（含软删记录）。
func GetPlan(ctx context.Context, db *gorm.DB, planID uint) (model.VipPlan, error) {
	if db == nil {
		return model.VipPlan{}, gorm.ErrInvalidDB
	}
	var plan model.VipPlan
	err := db.WithContext(ctx).Unscoped().First(&plan, planID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.VipPlan{}, ErrNotFound
	}
	return plan, err
}

// CreatePlan 创建套餐。
func CreatePlan(ctx context.Context, db *gorm.DB, in CreatePlanInput) (model.VipPlan, error) {
	if db == nil {
		return model.VipPlan{}, gorm.ErrInvalidDB
	}
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return model.VipPlan{}, ErrInvalidArgument
	}
	if in.DurationDays <= 0 {
		return model.VipPlan{}, ErrInvalidArgument
	}
	if in.Price < 0 {
		return model.VipPlan{}, ErrInvalidArgument
	}
	plan := model.VipPlan{
		Name:     name,
		Features: strings.TrimSpace(in.Description),
		Price:    in.Price,
		Duration: in.DurationDays,
	}
	if err := db.WithContext(ctx).Create(&plan).Error; err != nil {
		return model.VipPlan{}, err
	}
	return plan, nil
}

// UpdatePlan 部分更新套餐。
func UpdatePlan(ctx context.Context, db *gorm.DB, planID uint, patch UpdatePlanPatch) (model.VipPlan, error) {
	plan, err := GetPlan(ctx, db, planID)
	if err != nil {
		return model.VipPlan{}, err
	}
	if patch.UpdateName {
		name := strings.TrimSpace(patch.Name)
		if name == "" {
			return model.VipPlan{}, ErrInvalidArgument
		}
		plan.Name = name
	}
	if patch.UpdateDescription {
		plan.Features = strings.TrimSpace(patch.Description)
	}
	if patch.UpdatePrice {
		if patch.Price < 0 {
			return model.VipPlan{}, ErrInvalidArgument
		}
		plan.Price = patch.Price
	}
	if patch.UpdateDurationDays {
		if patch.DurationDays <= 0 {
			return model.VipPlan{}, ErrInvalidArgument
		}
		plan.Duration = patch.DurationDays
	}
	if err := db.WithContext(ctx).Save(&plan).Error; err != nil {
		return model.VipPlan{}, err
	}
	return plan, nil
}

// DeletePlan 软删除套餐。
func DeletePlan(ctx context.Context, db *gorm.DB, planID uint) error {
	if db == nil {
		return gorm.ErrInvalidDB
	}
	var plan model.VipPlan
	err := db.WithContext(ctx).First(&plan, planID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	return db.WithContext(ctx).Delete(&plan).Error
}

// BootstrapPlans 空表时写入默认套餐。
func BootstrapPlans(ctx context.Context, db *gorm.DB) (created int, err error) {
	if db == nil {
		return 0, gorm.ErrInvalidDB
	}
	var count int64
	if err := db.WithContext(ctx).Model(&model.VipPlan{}).Count(&count).Error; err != nil {
		return 0, err
	}
	if count > 0 {
		return 0, nil
	}
	defaults := []model.VipPlan{
		{Name: "月度 VIP", Price: 99, Duration: 30, Features: "月卡套餐"},
		{Name: "季度 VIP", Price: 268, Duration: 90, Features: "季度套餐"},
		{Name: "年度 VIP", Price: 899, Duration: 365, Features: "年度套餐"},
	}
	if err := db.WithContext(ctx).Create(&defaults).Error; err != nil {
		return 0, err
	}
	return len(defaults), nil
}
