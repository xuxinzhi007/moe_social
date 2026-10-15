package landingdata

import (
	"context"
	"time"

	landingbiz "backend/internal/biz/landing"
	"backend/model"

	"gorm.io/gorm"
)

type feedbackStore struct {
	repo *FeedbackRepo
}

// NewFeedbackStore 构造 biz.FeedbackStore（P4-D1）。
func NewFeedbackStore(db *gorm.DB) landingbiz.FeedbackStore {
	if db == nil {
		return nil
	}
	return feedbackStore{repo: NewFeedbackRepo(db)}
}

func (s feedbackStore) CountRecentByEmail(ctx context.Context, email string, since time.Time) (int64, error) {
	return s.repo.CountRecentByEmail(ctx, email, since)
}

func (s feedbackStore) Create(ctx context.Context, row *model.LandingFeedback) error {
	return s.repo.Create(ctx, row)
}
