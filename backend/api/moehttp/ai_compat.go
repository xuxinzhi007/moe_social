package moehttp

import (
	"context"

	ailogic "backend/api/internal/logic/ai"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const PilotNativeAiCompatRoutes = 14

func RegisterAiCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.AIApp == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/ai/agents", aiListAgents(svcCtx))
	r.PUT("/api/ai/agents", aiUpsertAgent(svcCtx))
	r.DELETE("/api/ai/agents", aiDeleteAgent(svcCtx))
	r.GET("/api/ai/agents/public", aiListPublicAgents(svcCtx))
	r.GET("/api/ai/config", aiGetUserConfig(svcCtx))
	r.PUT("/api/ai/config", aiUpsertUserConfig(svcCtx))
	r.GET("/api/ai/lorebooks", aiListLorebooks(svcCtx))
	r.PUT("/api/ai/lorebooks", aiUpsertLorebook(svcCtx))
	r.DELETE("/api/ai/lorebooks", aiDeleteLorebook(svcCtx))
	r.GET("/api/ai/memory/settings", aiGetAiMemorySettings(svcCtx))
	r.PUT("/api/ai/memory/settings", aiPutAiMemorySettings(svcCtx))
	r.GET("/api/ai/providers", aiListProviders(svcCtx))
	r.PUT("/api/ai/providers", aiUpsertProvider(svcCtx))
	r.DELETE("/api/ai/providers", aiDeleteProvider(svcCtx))
}

func aiListAgents(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.EmptyReq) (any, error) {
		l := ailogic.NewListAgentsLogic(ctx, svcCtx)
		return l.ListAgents(req)
	})
}

func aiUpsertAgent(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AiResourceUpsertReq) (any, error) {
		l := ailogic.NewUpsertAgentLogic(ctx, svcCtx)
		return l.UpsertAgent(req)
	})
}

func aiDeleteAgent(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AiResourceDeleteReq) (any, error) {
		l := ailogic.NewDeleteAgentLogic(ctx, svcCtx)
		return l.DeleteAgent(req)
	})
}

func aiListPublicAgents(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.ListPublicAiAgentsReq) (any, error) {
		l := ailogic.NewListPublicAgentsLogic(ctx, svcCtx)
		return l.ListPublicAgents(req)
	})
}

func aiGetUserConfig(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.EmptyReq) (any, error) {
		l := ailogic.NewGetUserConfigLogic(ctx, svcCtx)
		return l.GetUserConfig(req)
	})
}

func aiUpsertUserConfig(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AiUserConfigReq) (any, error) {
		l := ailogic.NewUpsertUserConfigLogic(ctx, svcCtx)
		return l.UpsertUserConfig(req)
	})
}

func aiListLorebooks(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.EmptyReq) (any, error) {
		l := ailogic.NewListLorebooksLogic(ctx, svcCtx)
		return l.ListLorebooks(req)
	})
}

func aiUpsertLorebook(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AiLorebookUpsertReq) (any, error) {
		l := ailogic.NewUpsertLorebookLogic(ctx, svcCtx)
		return l.UpsertLorebook(req)
	})
}

func aiDeleteLorebook(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AiResourceDeleteReq) (any, error) {
		l := ailogic.NewDeleteLorebookLogic(ctx, svcCtx)
		return l.DeleteLorebook(req)
	})
}

func aiGetAiMemorySettings(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.EmptyReq) (any, error) {
		l := ailogic.NewGetAiMemorySettingsLogic(ctx, svcCtx)
		return l.GetAiMemorySettings(req)
	})
}

func aiPutAiMemorySettings(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AiMemorySettingsReq) (any, error) {
		l := ailogic.NewPutAiMemorySettingsLogic(ctx, svcCtx)
		return l.PutAiMemorySettings(req)
	})
}

func aiListProviders(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.EmptyReq) (any, error) {
		l := ailogic.NewListProvidersLogic(ctx, svcCtx)
		return l.ListProviders(req)
	})
}

func aiUpsertProvider(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AiResourceUpsertReq) (any, error) {
		l := ailogic.NewUpsertProviderLogic(ctx, svcCtx)
		return l.UpsertProvider(req)
	})
}

func aiDeleteProvider(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AiResourceDeleteReq) (any, error) {
		l := ailogic.NewDeleteProviderLogic(ctx, svcCtx)
		return l.DeleteProvider(req)
	})
}
