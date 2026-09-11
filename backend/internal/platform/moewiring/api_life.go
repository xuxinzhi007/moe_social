package moewiring

import (
	"backend/internal/platform/appdb"
	lifeapp "backend/internal/service/life"
	"backend/pkg/conf"
)

const livingWorldIntervalSeconds = 5 * 60

// LifeAPIInProcessEnabled reports whether the life engine should run in-process.
func LifeAPIInProcessEnabled() bool {
	return conf.LifeEngineEnabled() || conf.DomainInProcess("life")
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
