package moewiring

import (
	"backend/internal/platform/appdb"
	landingapp "backend/internal/service/landing"
	"backend/pkg/conf"
)

// LandingAPIInProcessEnabled config.yaml: moe.landing_api_in_process
func LandingAPIInProcessEnabled() bool {
	return conf.DomainInProcess("landing")
}

// NewAPILandingService API 进程内 Landing 应用服务。
func NewAPILandingService() (*landingapp.AppService, error) {
	if !LandingAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return landingapp.New(db), nil
}
