package moewiring

import (
	behaviorapp "backend/internal/service/behavior"
	"backend/utils"
)

// BehaviorAPIInProcessEnabled config.yaml: moe.behavior_api_in_process
func BehaviorAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.behavior_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.behavior_api_in_process"}, false)
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
