package handler

import (
	"net/http"

	ai "backend/api/internal/handler/ai"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

func RegisterAiConfigRoutes(server *rest.Server, serverCtx *svc.ServiceContext) {
	server.AddRoutes(
		[]rest.Route{
			{
				Method:  http.MethodGet,
				Path:    "/api/ai/config",
				Handler: ai.GetUserConfigHandler(serverCtx),
			},
			{
				Method:  http.MethodPut,
				Path:    "/api/ai/config",
				Handler: ai.UpsertUserConfigHandler(serverCtx),
			},
		},
	)
}
