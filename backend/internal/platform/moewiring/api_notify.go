package moewiring

import (
	notifyapp "backend/internal/service/notify"
	"backend/utils"
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
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return notifyapp.New(db), nil
}
