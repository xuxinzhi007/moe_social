package runserver

import (
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
)

func wireCompanionServices(rep *wireReporter, ctx *svc.ServiceContext) {
	if ctx == nil {
		return
	}
	if moewiring.CompanionAPIInProcessEnabled() {
		companionApp, err := moewiring.NewAPICompanionService(ctx.LifeApp)
		if err != nil {
			rep.domainWarn("companion", "db", err.Error())
		} else if companionApp != nil {
			ctx.CompanionApp = companionApp
		}
	}
}
