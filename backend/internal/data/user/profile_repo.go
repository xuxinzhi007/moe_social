package userdata

import (
	userbiz "backend/internal/biz/user"

	"gorm.io/gorm"
)

// NewProfileStore 构造 biz.ProfileStore（委托 UserStore，P4-D3+）。
func NewProfileStore(db *gorm.DB) userbiz.ProfileStore {
	return NewUserStore(db)
}
