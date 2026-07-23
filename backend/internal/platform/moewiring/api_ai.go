package moewiring

import (
	"fmt"

	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
	aiapp "backend/internal/service/ai"
	"backend/utils"
)

// AIAPIInProcessEnabled config.yaml: moe.ai_api_in_process
func AIAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.ai_api_in_process")
}

// NewAPIAIService API 进程内 AI 资源应用服务。
func NewAPIAIService() (*aiapp.AppService, error) {
	if !AIAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, fmt.Errorf("ensure AI resources database: %w", err)
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	store := aidata.NewStore(db)
	resources := aibiz.NewResourcesUsecase(store)
	return aiapp.New(resources), nil
}
