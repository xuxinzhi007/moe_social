package moewiring

import (
	"fmt"

	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
	"backend/internal/platform/appdb"
	aiapp "backend/internal/service/ai"
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
	db, err := appdb.Open()
	if err != nil {
		return nil, fmt.Errorf("ensure AI resources database: %w", err)
	}
	store := aidata.NewStore(db)
	resources := aibiz.NewResourcesUsecase(store)
	return aiapp.New(resources), nil
}
