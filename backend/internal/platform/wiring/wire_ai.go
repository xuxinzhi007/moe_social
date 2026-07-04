package runserver

import (
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
)

func wireAIServices(rep *wireReporter, ctx *svc.ServiceContext) {
	if ctx == nil {
		return
	}
	if moewiring.AIAPIInProcessEnabled() {
		aiApp, err := moewiring.NewAPIAIService()
		if err != nil {
			rep.domainWarn("ai", "db", err.Error())
		} else if aiApp != nil {
			ctx.AIApp = aiApp
		}
	}
	if moewiring.LLMAPIInProcessEnabled() {
		llmApp, err := moewiring.NewAPILLMService()
		if err != nil {
			rep.domainWarn("llm", "db", err.Error())
		} else if llmApp != nil {
			ctx.LLMApp = llmApp
		}
	}
	if moewiring.APIInProcessEnabled() {
		appPort := moewiring.NewAppAdapter(ctx.PostApp, ctx.LLMApp)
		adm, err := moewiring.NewAPIAdminService(appPort)
		if err != nil {
			rep.domainWarn("moe", "db", err.Error())
		} else if adm != nil {
			ctx.MoeAdmin = adm
		}
	}
}
