package moewiring

import (
	adminapp "backend/internal/service/admin"
	"backend/utils"
)

// AdminReadonlyAPIInProcessEnabled config.yaml: moe.admin_readonly_api_in_process
func AdminReadonlyAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.admin_readonly_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.admin_readonly_api_in_process"}, false)
}

// NewAPIAdminReadonlyService API 进程内 Admin 只读应用服务。
func NewAPIAdminReadonlyService() (*adminapp.AppService, error) {
	if !AdminReadonlyAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return adminapp.New(db), nil
}
