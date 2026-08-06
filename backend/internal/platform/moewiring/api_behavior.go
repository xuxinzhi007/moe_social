package moewiring

import (
	"backend/internal/platform/appdb"
	behaviorapp "backend/internal/service/behavior"
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
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return behaviorapp.New(db), nil
}
