package bootstrap

import (
	platformsvc "backend/internal/platform/svc"
	llmapp "backend/internal/service/llm"
	postapp "backend/internal/service/post"
)

type Deps struct {
	PostApp *postapp.AppService
	LLMApp  *llmapp.AppService
}

func DepsFromServiceContext(svcCtx *platformsvc.ServiceContext) Deps {
	if svcCtx == nil {
		return Deps{}
	}
	return Deps{
		PostApp: svcCtx.Domains.Community.PostApp,
		LLMApp:  svcCtx.Domains.AI.LLMApp,
	}
}
