// Package commentapp 评论域应用服务。
package commentapp

import (
	commentbiz "backend/internal/biz/comment"
	commentdata "backend/internal/data/comment"
	"context"
	"gorm.io/gorm"
)

// Package commentapp 评论域应用服务。

// AppService 评论应用层。
type AppService struct {
	store                  commentbiz.CommentStore
	companionEventRecorder CompanionEventRecorder
}

// CompanionEventRecorder is an optional cross-domain event projection hook.
type CompanionEventRecorder func(context.Context, uint, string, uint, map[string]interface{}) error

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: commentdata.NewStore(db)}
}

// SetCompanionEventRecorder enables optional social-to-companion projection.
func (s *AppService) SetCompanionEventRecorder(recorder CompanionEventRecorder) {
	if s == nil {
		return
	}
	s.companionEventRecorder = recorder
}
