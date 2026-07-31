package runserver

import (
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
)

func wirePetServices(rep *wireReporter, ctx *svc.ServiceContext) {
	if ctx == nil {
		return
	}
	petApp, err := moewiring.NewAPIPetService()
	if err != nil {
		rep.domainWarn("pet", "db", err.Error())
		return
	}
	if petApp != nil {
		ctx.PetApp = petApp
	}
}
