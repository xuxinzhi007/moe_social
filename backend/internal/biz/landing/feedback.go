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

// SubmitInput 提交落地页反馈。
type SubmitInput struct {
	Email     string
	Category  string
	Content   string
	Source    string
	ClientIP  string
	UserAgent string
}

// Submit 保存反馈并尝试飞书通知。
func Submit(ctx context.Context, db *gorm.DB, in SubmitInput) (uint64, error) {
	if db == nil {
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
	var recentCount int64
	if err := db.WithContext(ctx).Model(&model.LandingFeedback{}).
		Where("email = ? AND created_at >= ?", email, since).
		Count(&recentCount).Error; err != nil {
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
	if err := db.WithContext(ctx).Create(&row).Error; err != nil {
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
func List(ctx context.Context, db *gorm.DB, f ListFilter) (ListResult, error) {
	if db == nil {
		return ListResult{}, gorm.ErrInvalidDB
	}
	page := f.Page
	if page <= 0 {
		page = 1
	}
	pageSize := f.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

	q := db.WithContext(ctx).Model(&model.LandingFeedback{})
	category := strings.TrimSpace(f.Category)
	if category != "" && category != "all" {
		q = q.Where("category = ?", NormalizeCategory(category))
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
