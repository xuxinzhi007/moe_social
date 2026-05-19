package handler

import (
	"net/http"

	ai "backend/api/internal/handler/ai"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

func RegisterAiResourceRoutes(server *rest.Server, serverCtx *svc.ServiceContext) {
	server.AddRoutes(
		[]rest.Route{
			{Method: http.MethodGet, Path: "/api/ai/providers", Handler: ai.ListProvidersHandler(serverCtx)},
			{Method: http.MethodPut, Path: "/api/ai/providers", Handler: ai.UpsertProviderHandler(serverCtx)},
			{Method: http.MethodDelete, Path: "/api/ai/providers", Handler: ai.DeleteProviderHandler(serverCtx)},
			{Method: http.MethodGet, Path: "/api/ai/agents", Handler: ai.ListAgentsHandler(serverCtx)},
			{Method: http.MethodGet, Path: "/api/ai/agents/public", Handler: ai.ListPublicAgentsHandler(serverCtx)},
			{Method: http.MethodPut, Path: "/api/ai/agents", Handler: ai.UpsertAgentHandler(serverCtx)},
			{Method: http.MethodDelete, Path: "/api/ai/agents", Handler: ai.DeleteAgentHandler(serverCtx)},
			{Method: http.MethodGet, Path: "/api/ai/lorebooks", Handler: ai.ListLorebooksHandler(serverCtx)},
			{Method: http.MethodPut, Path: "/api/ai/lorebooks", Handler: ai.UpsertLorebookHandler(serverCtx)},
			{Method: http.MethodDelete, Path: "/api/ai/lorebooks", Handler: ai.DeleteLorebookHandler(serverCtx)},
		},
	)
}
