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
