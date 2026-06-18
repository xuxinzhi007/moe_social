package landingapp

import (
	"gorm.io/gorm"
	landingbiz "backend/internal/biz/landing"
	landingdata "backend/internal/data/landing"
)

// AppService Landing HTTP/RPC 应用层。
type AppService struct {
	feedback landingbiz.FeedbackStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{feedback: landingdata.NewFeedbackStore(db)}
}
