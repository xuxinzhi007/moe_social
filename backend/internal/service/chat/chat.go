// Package chatapp 私信域应用服务（F106 Hybrid）。
package chatapp

import (
	chatbiz "backend/internal/biz/chat"
	chatdata "backend/internal/data/chat"
	"gorm.io/gorm"
)

// Package chatapp 私信域应用服务（F106 Hybrid）。

// AppService 私信应用层。
type AppService struct {
	pm       chatbiz.PrivateMessageStore
	db       *gorm.DB
	delivery chatbiz.DeliveryDeps
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{pm: chatdata.NewStore(db), db: db}
}

// DB 返回私信域数据库连接（离线通知兜底等）。
func (s *AppService) DB() *gorm.DB {
	if s == nil {
		return nil
	}
	return s.db
}

// PrivateMessageStore 返回私信持久化接口。
func (s *AppService) PrivateMessageStore() chatbiz.PrivateMessageStore {
	if s == nil {
		return nil
	}
	return s.pm
}

// SetDelivery 绑定在线推送和离线站内通知。未绑定时只保存消息。
func (s *AppService) SetDelivery(deps chatbiz.DeliveryDeps) {
	if s == nil {
		return
	}
	s.delivery = deps
}
