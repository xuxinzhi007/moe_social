package moewiring

import (
	"backend/internal/platform/appdb"
	vipadmin "backend/internal/service/vip"
)

// NewAPIVipAdminService 在 API 进程装配 VIP Admin（需已配置数据库）。
func NewAPIVipAdminService() (*vipadmin.AdminService, error) {
	if !VIPAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return vipadmin.NewAdmin(db), nil
}
