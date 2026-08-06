package moewiring

import (
	"context"

	"backend/internal/adapter/moeconfig"
	companionbiz "backend/internal/biz/companion"
	lifebiz "backend/internal/biz/life"
	companiondata "backend/internal/data/companion"
	"backend/internal/platform/appdb"
	companionapp "backend/internal/service/companion"
	lifeapp "backend/internal/service/life"
	"backend/pkg/llminference"
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
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	// 复用全局 LLM 推理配置
	inf := moeconfig.InferenceFromViper()
	model := llminference.ResolveModelName(context.Background(), inf, inf.DefaultModel)

	// 尝试获取 life store（可选依赖）
	var lifeStore lifebiz.Store
	if lifeApp != nil {
		lifeStore = lifeApp.Store()
	}

	store := companiondata.NewStore(db)
	if store == nil {
		return nil, nil
	}
	engine := companionbiz.NewEngine(store, lifeStore, inf, model)
	hub := companionbiz.NewCompanionWSHub()
	// 绑定居民免死：Life tick 查询 companion_profiles.life_entity_id。
	if lifeApp != nil && lifeApp.Engine() != nil {
		lifeApp.Engine().SetBoundEntitySource(&companionBoundEntitySource{db: db})
		lifeApp.Engine().SetEventObserver(engine.ObserveLifeEvent)
	}
	return companionapp.New(engine, hub, db), nil
}
