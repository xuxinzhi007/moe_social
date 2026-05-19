package handler

import (
	"net/http"

	userhandler "backend/api/internal/handler/user"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

// RegisterFeishuAuthRoutes 飞书 OAuth 登录（手工维护，避免 goctl 覆盖）。
func RegisterFeishuAuthRoutes(server *rest.Server, serverCtx *svc.ServiceContext) {
	server.AddRoutes(
		[]rest.Route{
			{
				Method:  http.MethodGet,
				Path:    "/api/auth/feishu/authorize-url",
				Handler: userhandler.FeishuAuthorizeURLHandler(serverCtx),
			},
			{
				Method:  http.MethodPost,
				Path:    "/api/auth/feishu/login",
				Handler: userhandler.FeishuLoginHandler(serverCtx),
			},
			{
				Method:  http.MethodGet,
				Path:    "/api/auth/feishu/callback",
				Handler: userhandler.FeishuOAuthCallbackHandler(serverCtx),
			},
			{
				Method:  http.MethodGet,
				Path:    "/api/auth/feishu/public-config",
				Handler: userhandler.FeishuPublicConfigHandler(),
			},
		},
	)
}
