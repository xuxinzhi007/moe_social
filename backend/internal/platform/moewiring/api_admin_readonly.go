package moewiring

import (
	"backend/internal/platform/appdb"
	adminapp "backend/internal/service/admin"
)

// AdminReadonlyAPIInProcessEnabled config.yaml: moe.admin_readonly_api_in_process
func AdminReadonlyAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.admin_readonly_api_in_process")
}

// NewAPIAdminReadonlyService API 进程内 Admin 只读应用服务。
func NewAPIAdminReadonlyService() (*adminapp.AppService, error) {
	if !AdminReadonlyAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return adminapp.New(db), nil
}
