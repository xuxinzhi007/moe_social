package runserver

import (
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
)

func wireAccessServices(rep *wireReporter, ctx *svc.ServiceContext) {
	if ctx == nil {
		return
	}
	if moewiring.VIPAPIInProcessEnabled() {
		vipAdm, err := moewiring.NewAPIVipAdminService()
		if err != nil {
			rep.domainWarn("vip", "db", err.Error())
		} else if vipAdm != nil {
			ctx.VipAdmin = vipAdm
		}
	}
	if moewiring.UserAPIInProcessEnabled() {
		userApp, err := moewiring.NewAPIUserService()
		if err != nil {
			rep.domainWarn("user", "db", err.Error())
		} else if userApp != nil {
			ctx.UserApp = userApp
		}
	}
	if moewiring.LandingAPIInProcessEnabled() {
		landingApp, err := moewiring.NewAPILandingService()
		if err != nil {
			rep.domainWarn("landing", "db", err.Error())
		} else if landingApp != nil {
			ctx.LandingApp = landingApp
		}
	}
	if moewiring.AdminReadonlyAPIInProcessEnabled() {
		adminApp, err := moewiring.NewAPIAdminReadonlyService()
		if err != nil {
			rep.domainWarn("admin", "db", err.Error())
		} else if adminApp != nil {
			ctx.AdminApp = adminApp
		}
	}
}
