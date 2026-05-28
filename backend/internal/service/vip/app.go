package vipadmin

import (
	"gorm.io/gorm"
)

// AppService VIP 域应用服务（P4-D4；与 AdminService 同构）。
type AppService = AdminService

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return NewAdmin(db)
}
