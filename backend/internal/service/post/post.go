package postapp

import (
	"gorm.io/gorm"
	postbiz "backend/internal/biz/post"
	checkinbiz "backend/internal/biz/checkin"
	postdata "backend/internal/data/post"
	checkindata "backend/internal/data/checkin"
	mediabiz "backend/internal/biz/media"
)

// AppService 帖子应用层。
type AppService struct {
	store                     postbiz.PostStore
	checkinStore              checkinbiz.CheckInStore
	handDrawRequireModeration bool
	imageCfg                  mediabiz.ImageConfig
}

// New 构造 AppService。
func New(db *gorm.DB, handDrawRequireModeration bool, imageCfg mediabiz.ImageConfig) *AppService {
	return &AppService{
		store:                     postdata.NewStore(db),
		checkinStore:              checkindata.NewStore(db),
		handDrawRequireModeration: handDrawRequireModeration,
		imageCfg:                  imageCfg,
	}
}
