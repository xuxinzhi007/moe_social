package moewiring

import (
	"context"
	"fmt"
	"strconv"

	aibiz "backend/internal/biz/ai"
	arenabiz "backend/internal/biz/arena"
	companionbiz "backend/internal/biz/companion"
	lifebiz "backend/internal/biz/life"
	aidata "backend/internal/data/ai"
	arenadata "backend/internal/data/arena"
	companiondata "backend/internal/data/companion"
	"backend/internal/platform/appdb"
	companionapp "backend/internal/service/companion"
	lifeapp "backend/internal/service/life"
	"backend/pkg/conf"
	"backend/pkg/llminference"
)

// CompanionAPIInProcessEnabled reports whether the companion service should run in-process.
func CompanionAPIInProcessEnabled() bool {
	return conf.DomainInProcess("companion")
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
	inf := conf.Inference()
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
	// K3 小家闲聊羁绊门槛：从 arena 存档解析 OwnedHero.Bond，未拥有按 0 计。
	arenaUC := arenabiz.NewUsecase(arenadata.NewRepo(db))
	engine.SetHeroBondResolver(func(ctx context.Context, userID uint, heroSlug string) (int, error) {
		state, err := arenaUC.GetState(ctx, strconv.FormatUint(uint64(userID), 10))
		if err != nil {
			return 0, fmt.Errorf("resolve arena bond for user %d: %w", userID, err)
		}
		for _, owned := range state.OwnedHeroes {
			if owned.HeroID == heroSlug {
				return owned.Bond, nil
			}
		}
		return 0, nil
	})
	hub := companionbiz.NewCompanionWSHub()
	// 绑定居民免死：Life tick 查询 companion_profiles.life_entity_id。
	if lifeApp != nil && lifeApp.Engine() != nil {
		lifeApp.Engine().SetBoundEntitySource(&companionBoundEntitySource{db: db})
		lifeApp.Engine().SetEventObserver(engine.ObserveLifeEvent)
	}
	svc := companionapp.New(engine, hub, db)
	if svc != nil {
		if aiStore := aidata.NewStore(db); aiStore != nil {
			svc.UseInferenceResolver(func(ctx context.Context, userID uint) (*llminference.Config, error) {
				return aibiz.ResolveActiveInference(ctx, aiStore, userID)
			})
		}
	}
	return svc, nil
}
