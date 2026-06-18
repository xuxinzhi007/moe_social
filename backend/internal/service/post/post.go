package postapp

import (
	"gorm.io/gorm"
	postbiz "backend/internal/biz/post"
	postdata "backend/internal/data/post"
	mediabiz "backend/internal/biz/media"
)

// AppService 帖子应用层。
type AppService struct {
	store                     postbiz.PostStore
	handDrawRequireModeration bool
	imageCfg                  mediabiz.ImageConfig
}

// New 构造 AppService。
func New(db *gorm.DB, handDrawRequireModeration bool, imageCfg mediabiz.ImageConfig) *AppService {
	return &AppService{
		store:                     postdata.NewStore(db),
		handDrawRequireModeration: handDrawRequireModeration,
		imageCfg:                  imageCfg,
	}
}
