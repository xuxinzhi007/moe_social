package moewiring

import (
	"backend/internal/platform/appdb"
	adminapp "backend/internal/service/admin"
	"backend/pkg/conf"
)

// AdminReadonlyAPIInProcessEnabled config.yaml: moe.admin_readonly_api_in_process
func AdminReadonlyAPIInProcessEnabled() bool {
	return conf.DomainInProcess("admin_readonly")
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
