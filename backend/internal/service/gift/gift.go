// Package giftapp 礼物域应用服务。
package giftapp

import (
	"gorm.io/gorm"
	giftbiz "backend/internal/biz/gift"
	giftdata "backend/internal/data/gift"
)

// Package giftapp 礼物域应用服务。

// AppService 礼物应用层。
type AppService struct {
	store giftbiz.GiftStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: giftdata.NewStore(db)}
}
