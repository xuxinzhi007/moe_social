// Package adminapp Admin 只读应用服务（Sprint S3）。
package adminapp

import (
	"gorm.io/gorm"
	notifybiz "backend/internal/biz/notify"
	notifydata "backend/internal/data/notify"
	adminbiz "backend/internal/biz/admin"
	admindata "backend/internal/data/admin"
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
