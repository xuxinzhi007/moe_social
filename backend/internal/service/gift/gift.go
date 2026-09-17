// Package giftapp 礼物域应用服务。
package giftapp

import (
	giftbiz "backend/internal/biz/gift"
	notifybiz "backend/internal/biz/notify"
	giftdata "backend/internal/data/gift"
	notifydata "backend/internal/data/notify"
	"gorm.io/gorm"
)

// AppService 礼物应用层。
type AppService struct {
	store  giftbiz.GiftStore
	notify notifybiz.NotifyStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{
		store:  giftdata.NewStore(db),
		notify: notifydata.NewStore(db),
	}
}
