// Package adminapp Admin 只读应用服务（Sprint S3）。
package adminapp

import (
	adminbiz "backend/internal/biz/admin"
	notifybiz "backend/internal/biz/notify"
	admindata "backend/internal/data/admin"
	notifydata "backend/internal/data/notify"
	"gorm.io/gorm"
)

// Package adminapp Admin 只读应用服务（Sprint S3）。

// AppService Admin 只读 HTTP/RPC 应用层。
type AppService struct {
	db     *gorm.DB
	store  adminbiz.AdminStore
	notify notifybiz.NotifyStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{
		db:     db,
		store:  admindata.NewStore(db),
		notify: notifydata.NewStore(db),
	}
}
