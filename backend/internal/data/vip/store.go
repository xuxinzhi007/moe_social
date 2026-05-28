package vipdata

import (
	"context"
	"errors"
	"strings"

	vipbiz "backend/internal/biz/vip"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.VipStore（P4-D4）。
func NewStore(db *gorm.DB) vipbiz.VipStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) vipbiz.VipStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) ListPlans(ctx context.Context, f vipbiz.ListPlansFilter) ([]model.VipPlan, int64, error) {
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

	q := s.db.WithContext(ctx).Model(&model.VipPlan{})
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
	err := q.Order("id ASC").Offset(offset).Limit(pageSize).Find(&rows).Error
	return rows, total, err
}

func (s *store) ListAllPlans(ctx context.Context) ([]model.VipPlan, error) {
	var rows []model.VipPlan
	err := s.db.WithContext(ctx).Order("id ASC").Find(&rows).Error
	return rows, err
}

func (s *store) GetPlan(ctx context.Context, planID uint) (model.VipPlan, error) {
	var plan model.VipPlan
	err := s.db.WithContext(ctx).Unscoped().First(&plan, planID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.VipPlan{}, vipbiz.ErrNotFound
	}
	return plan, err
}

func (s *store) CreatePlan(ctx context.Context, plan *model.VipPlan) error {
	return s.db.WithContext(ctx).Create(plan).Error
}

func (s *store) SavePlan(ctx context.Context, plan *model.VipPlan) error {
	return s.db.WithContext(ctx).Save(plan).Error
}

func (s *store) FindActivePlan(ctx context.Context, planID uint) (model.VipPlan, error) {
	var plan model.VipPlan
	err := s.db.WithContext(ctx).First(&plan, planID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.VipPlan{}, vipbiz.ErrNotFound
	}
	return plan, err
}

func (s *store) DeletePlan(ctx context.Context, planID uint) error {
	return s.db.WithContext(ctx).Delete(&model.VipPlan{}, planID).Error
}

func (s *store) CountPlans(ctx context.Context) (int64, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&model.VipPlan{}).Count(&count).Error
	return count, err
}

func (s *store) CreatePlans(ctx context.Context, plans []model.VipPlan) error {
	return s.db.WithContext(ctx).Create(&plans).Error
}
