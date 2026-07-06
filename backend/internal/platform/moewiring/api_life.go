package moewiring

import (
	lifeapp "backend/internal/service/life"
	"backend/utils"
)

// LifeAPIInProcessEnabled reports whether the life engine should run in-process.
func LifeAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.life_engine_enabled") || domainInProcessEnabled("moe.life_api_in_process")
}

// NewAPILifeService creates the life AppService when the feature flag is on.
func NewAPILifeService() (*lifeapp.AppService, error) {
	if !LifeAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	// moeconfig import reserved for future LLM config
	return lifeapp.New(db, lifeapp.Config{
		TickInterval: 5, // seconds
	}), nil
}
