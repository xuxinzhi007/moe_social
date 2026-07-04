package runserver

import (
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
)

func wireGameServices(rep *wireReporter, ctx *svc.ServiceContext) {
	if ctx == nil {
		return
	}
	if moewiring.GameAPIInProcessEnabled() {
		gameApp, err := moewiring.NewAPIGameService()
		if err != nil {
			rep.domainWarn("game", "db", err.Error())
		} else if gameApp != nil {
			ctx.GameApp = gameApp
		}
	}
}
