package runserver

import (
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
)

func wireLifeServices(rep *wireReporter, ctx *svc.ServiceContext) {
	if ctx == nil {
		return
	}
	if moewiring.LifeAPIInProcessEnabled() {
		lifeApp, err := moewiring.NewAPILifeService()
		if err != nil {
			rep.domainWarn("life", "db", err.Error())
		} else if lifeApp != nil {
			ctx.LifeApp = lifeApp
		}
	}
}
