package moewiring

import (
	"backend/internal/platform/appdb"
	lifeapp "backend/internal/service/life"
)

const livingWorldIntervalSeconds = 5 * 60

// LifeAPIInProcessEnabled reports whether the life engine should run in-process.
func LifeAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.life_engine_enabled") || domainInProcessEnabled("moe.life_api_in_process")
}

// NewAPILifeService creates the life AppService when the feature flag is on.
func NewAPILifeService() (*lifeapp.AppService, error) {
	if !LifeAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return lifeapp.New(db, lifeapp.Config{
		TickInterval:  livingWorldIntervalSeconds,
		FlushInterval: livingWorldIntervalSeconds,
	}), nil
}
