package runserver

import (
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
)

func wireArenaServices(rep *wireReporter, ctx *svc.ServiceContext) {
	if ctx == nil {
		return
	}
	arenaApp, err := moewiring.NewAPIArenaService()
	if err != nil {
		rep.domainWarn("arena", "db", err.Error())
		return
	}
	if arenaApp != nil {
		ctx.ArenaApp = arenaApp
	}
}
