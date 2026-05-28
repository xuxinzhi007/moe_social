package landingbiz

import (
	"context"
	"strings"
	"time"
	"unicode/utf8"

	"backend/model"
	"backend/utils"

	"gorm.io/gorm"
)

// FeedbackStore 落地页反馈持久化（P4-D1；默认由 data 层实现）。
type FeedbackStore interface {
	CountRecentByEmail(ctx context.Context, email string, since time.Time) (int64, error)
	Create(ctx context.Context, row *model.LandingFeedback) error
	List(ctx context.Context, category string, page, pageSize int32) (FeedbackListResult, error)
}

// FeedbackListResult 分页列表（biz 层视图）。
type FeedbackListResult struct {
	Rows  []model.LandingFeedback
	Total int64
}
type SubmitInput struct {
	Email     string
	Category  string
	Content   string
	Source    string
	ClientIP  string
	UserAgent string
}

// Submit 保存反馈并尝试飞书通知。
func Submit(ctx context.Context, store FeedbackStore, in SubmitInput) (uint64, error) {
	if store == nil {
		return 0, gorm.ErrInvalidDB
	}
	email, err := utils.NormalizeFeishuEmail(in.Email)
	if err != nil {
		return 0, ErrInvalidEmail
	}
	content := strings.TrimSpace(in.Content)
	if utf8.RuneCountInString(content) < 5 {
		return 0, ErrInvalidArgument
	}
	if utf8.RuneCountInString(content) > 2000 {
		return 0, ErrTooLong
	}
	category := NormalizeCategory(in.Category)
	source := strings.TrimSpace(in.Source)
	if source == "" {
		source = "official-site"
	}
	if len(source) > 64 {
		source = source[:64]
	}

	since := time.Now().Add(-1 * time.Hour)
	recentCount, err := store.CountRecentByEmail(ctx, email, since)
	if err != nil {
		return 0, err
	}
	if recentCount >= 5 {
		return 0, ErrRateLimited
	}

	row := model.LandingFeedback{
		Email:     email,
		Category:  category,
		Content:   content,
		Source:    source,
		ClientIP:  TruncateRunes(strings.TrimSpace(in.ClientIP), 64),
		UserAgent: TruncateRunes(strings.TrimSpace(in.UserAgent), 255),
		CreatedAt: time.Now(),
	}
	if err := store.Create(ctx, &row); err != nil {
		return 0, err
	}

	_ = utils.SendFeishuLandingFeedbackNotification(ctx, utils.LandingFeedbackNotification{
		ID:        row.ID,
		Email:     row.Email,
		Category:  row.Category,
		Content:   row.Content,
		Source:    row.Source,
		ClientIP:  row.ClientIP,
		CreatedAt: row.CreatedAt,
	})

	return uint64(row.ID), nil
}

// ListFilter 列表筛选。
type ListFilter struct {
	Page     int32
	PageSize int32
	Category string
}

// ListResult 分页列表。
type ListResult struct {
	Rows  []model.LandingFeedback
	Total int64
}

// List 分页查询落地页反馈。
func List(ctx context.Context, store FeedbackStore, f ListFilter) (ListResult, error) {
	if store == nil {
		return ListResult{}, gorm.ErrInvalidDB
	}
	category := strings.TrimSpace(f.Category)
	if category != "" && category != "all" {
		category = NormalizeCategory(category)
	} else {
		category = ""
	}
	raw, err := store.List(ctx, category, f.Page, f.PageSize)
	if err != nil {
		return ListResult{}, err
	}
	return ListResult{Rows: raw.Rows, Total: raw.Total}, nil
}
