package moewiring

import (
	vipadmin "backend/internal/service/vip"
	"backend/utils"
)

// NewAPIVipAdminService 在 API 进程装配 VIP Admin（需已配置数据库）。
func NewAPIVipAdminService() (*vipadmin.AdminService, error) {
	if !VIPAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return vipadmin.NewAdmin(db), nil
}
