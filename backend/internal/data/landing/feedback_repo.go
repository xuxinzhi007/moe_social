package landingdata

import (
	"context"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// FeedbackRepo 落地页反馈持久化（P4-D1 试点）。
type FeedbackRepo struct {
	db *gorm.DB
}

// NewFeedbackRepo 构造 repo。
func NewFeedbackRepo(db *gorm.DB) *FeedbackRepo {
	return &FeedbackRepo{db: db}
}

// CountRecentByEmail 统计邮箱在 since 之后的提交次数。
func (r *FeedbackRepo) CountRecentByEmail(ctx context.Context, email string, since time.Time) (int64, error) {
	if r.db == nil {
		return 0, gorm.ErrInvalidDB
	}
	var n int64
	err := r.db.WithContext(ctx).Model(&model.LandingFeedback{}).
		Where("email = ? AND created_at >= ?", email, since).
		Count(&n).Error
	return n, err
}

// Create 插入一条反馈。
func (r *FeedbackRepo) Create(ctx context.Context, row *model.LandingFeedback) error {
	if r.db == nil {
		return gorm.ErrInvalidDB
	}
	return r.db.WithContext(ctx).Create(row).Error
}

// ListFilter 列表筛选。
type ListFilter struct {
	Page     int32
	PageSize int32
	Category string
}

// ListResult 分页结果。
type ListResult struct {
	Rows  []model.LandingFeedback
	Total int64
}

// List 分页查询。
func (r *FeedbackRepo) List(ctx context.Context, category string, page, pageSize int32) (ListResult, error) {
	if r.db == nil {
		return ListResult{}, gorm.ErrInvalidDB
	}
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

	q := r.db.WithContext(ctx).Model(&model.LandingFeedback{})
	if category != "" {
		q = q.Where("category = ?", category)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return ListResult{}, err
	}

	var rows []model.LandingFeedback
	offset := int((page - 1) * pageSize)
	if err := q.Order("created_at DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return ListResult{}, err
	}
	return ListResult{Rows: rows, Total: total}, nil
}
