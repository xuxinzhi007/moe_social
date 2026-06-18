// Package communityapp 社区/群组域应用服务。
package communityapp

import (
	"gorm.io/gorm"
	postbiz "backend/internal/biz/post"
	postdata "backend/internal/data/post"
	communitybiz "backend/internal/biz/community"
	communitydata "backend/internal/data/community"
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
