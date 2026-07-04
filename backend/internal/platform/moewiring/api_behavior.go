package moewiring

import (
	behaviorapp "backend/internal/service/behavior"
	"backend/utils"
)

// BehaviorAPIInProcessEnabled config.yaml: moe.behavior_api_in_process
func BehaviorAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.behavior_api_in_process")
}

// NewAPIBehaviorService API 进程内 Behavior 应用服务。
func NewAPIBehaviorService() (*behaviorapp.AppService, error) {
	if !BehaviorAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return behaviorapp.New(db), nil
}
