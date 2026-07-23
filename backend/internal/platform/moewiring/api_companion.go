package moewiring

import (
	"context"

	"backend/internal/adapter/moeconfig"
	lifebiz "backend/internal/biz/life"
	lifeapp "backend/internal/service/life"
	companionapp "backend/internal/service/companion"
	"backend/pkg/llminference"
	"backend/utils"
)

// CompanionAPIInProcessEnabled reports whether the companion service should run in-process.
func CompanionAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.companion_api_in_process")
}

// NewAPICompanionService creates the companion AppService when the feature flag is on.
func NewAPICompanionService(lifeApp *lifeapp.AppService) (*companionapp.AppService, error) {
	if !CompanionAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	// 复用全局 LLM 推理配置
	inf := moeconfig.InferenceFromViper()
	model := llminference.ResolveModelName(context.Background(), inf, inf.DefaultModel)

	// 尝试获取 life store（可选依赖）
	var lifeStore lifebiz.Store
	if lifeApp != nil {
		lifeStore = lifeApp.Store()
	}

	return companionapp.New(db, companionapp.Deps{
		Inference: inf,
		Model:     model,
	}, lifeStore), nil
}
