package postapp

import (
	checkinbiz "backend/internal/biz/checkin"
	mediabiz "backend/internal/biz/media"
	postbiz "backend/internal/biz/post"
	checkindata "backend/internal/data/checkin"
	postdata "backend/internal/data/post"
	"context"
	"gorm.io/gorm"
)

// AppService 帖子应用层。
type AppService struct {
	store                     postbiz.PostStore
	checkinStore              checkinbiz.CheckInStore
	handDrawRequireModeration bool
	imageCfg                  mediabiz.ImageConfig
	companionEventRecorder    CompanionEventRecorder
}

// CompanionEventRecorder is an optional cross-domain event projection hook.
type CompanionEventRecorder func(context.Context, uint, string, uint, map[string]interface{}) error

// New 构造 AppService。
func New(db *gorm.DB, handDrawRequireModeration bool, imageCfg mediabiz.ImageConfig) *AppService {
	return &AppService{
		store:                     postdata.NewStore(db),
		checkinStore:              checkindata.NewStore(db),
		handDrawRequireModeration: handDrawRequireModeration,
		imageCfg:                  imageCfg,
	}
}

// SetCompanionEventRecorder enables optional social-to-companion projection.
func (s *AppService) SetCompanionEventRecorder(recorder CompanionEventRecorder) {
	if s == nil {
		return
	}
	s.companionEventRecorder = recorder
}
