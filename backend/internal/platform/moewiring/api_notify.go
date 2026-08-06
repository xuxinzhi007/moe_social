package moewiring

import (
	"backend/internal/platform/appdb"
	notifyapp "backend/internal/service/notify"
)

// NotifyAPIInProcessEnabled config.yaml: moe.notify_api_in_process
func NotifyAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.notify_api_in_process")
}

// NewAPINotifyService API 进程内 Notify 应用服务。
func NewAPINotifyService() (*notifyapp.AppService, error) {
	if !NotifyAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return notifyapp.New(db), nil
}
