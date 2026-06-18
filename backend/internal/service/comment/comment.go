// Package commentapp 评论域应用服务。
package commentapp

import (
	"gorm.io/gorm"
	commentbiz "backend/internal/biz/comment"
	commentdata "backend/internal/data/comment"
)

// Package commentapp 评论域应用服务。

// AppService 评论应用层。
type AppService struct {
	store commentbiz.CommentStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: commentdata.NewStore(db)}
}
