// Package communityapp 社区/群组域应用服务。
package communityapp

import (
	communitybiz "backend/internal/biz/community"
	postbiz "backend/internal/biz/post"
	communitydata "backend/internal/data/community"
	postdata "backend/internal/data/post"
	"gorm.io/gorm"
)

// Package communityapp 社区/群组域应用服务。

// AppService 社区应用层。
type AppService struct {
	store     communitybiz.CommunityStore
	postStore postbiz.PostStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{
		store:     communitydata.NewStore(db),
		postStore: postdata.NewStore(db),
	}
}
