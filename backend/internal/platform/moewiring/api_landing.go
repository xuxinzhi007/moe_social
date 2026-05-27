package moewiring

import (
	landingapp "backend/internal/service/landing"
	"backend/utils"
)

// LandingAPIInProcessEnabled config.yaml: moe.landing_api_in_process
func LandingAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.landing_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.landing_api_in_process"}, false)
}

// NewAPILandingService API 进程内 Landing 应用服务。
func NewAPILandingService() (*landingapp.AppService, error) {
	if !LandingAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return landingapp.New(db), nil
}
