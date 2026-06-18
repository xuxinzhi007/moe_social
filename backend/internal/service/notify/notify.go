// Package notifyapp 通知域应用服务（P4-D4）。
package notifyapp

import (
	"gorm.io/gorm"
	notifybiz "backend/internal/biz/notify"
	notifydata "backend/internal/data/notify"
)

// Package notifyapp 通知域应用服务（P4-D4）。

// AppService 通知应用层。
type AppService struct {
	store notifybiz.NotifyStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: notifydata.NewStore(db)}
}

// Store 返回持久化接口（Hybrid 内部复用）。
func (s *AppService) Store() notifybiz.NotifyStore {
	if s == nil {
		return nil
	}
	return s.store
}
