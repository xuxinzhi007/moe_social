// Package checkinapp 签到域应用服务。
package checkinapp

import (
	"gorm.io/gorm"
	checkinbiz "backend/internal/biz/checkin"
	checkindata "backend/internal/data/checkin"
)

// Package checkinapp 签到域应用服务。

// AppService 签到应用层。
type AppService struct {
	store checkinbiz.CheckInStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: checkindata.NewStore(db)}
}
