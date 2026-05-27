package moewiring

import (
	aiapp "backend/internal/service/ai"
	"backend/utils"
)

// AIAPIInProcessEnabled config.yaml: moe.ai_api_in_process
func AIAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.ai_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.ai_api_in_process"}, false)
}

// NewAPIAIService API 进程内 AI 资源应用服务。
func NewAPIAIService() (*aiapp.AppService, error) {
	if !AIAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return aiapp.New(db), nil
}
