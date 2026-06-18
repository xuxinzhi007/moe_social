// Package aiapp AI 资源域应用服务。
package aiapp

import (
	"gorm.io/gorm"
	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
)

// Package aiapp AI 资源域应用服务。

// AppService AI 资源应用层。
type AppService struct {
	store aibiz.AiStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: aidata.NewStore(db)}
}
