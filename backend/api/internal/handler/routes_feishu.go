package handler

import (
	"net/http"

	userhandler "backend/api/internal/handler/user"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

// RegisterFeishuRoutes 飞书绑定与测试卡片（手工维护，避免 goctl 覆盖）。
func RegisterFeishuRoutes(server *rest.Server, serverCtx *svc.ServiceContext) {
	server.AddRoutes(
		[]rest.Route{
			{
				Method:  http.MethodPut,
				Path:    "/api/user/feishu/bind",
				Handler: userhandler.BindFeishuHandler(serverCtx),
			},
			{
				Method:  http.MethodDelete,
				Path:    "/api/user/feishu/bind",
				Handler: userhandler.UnbindFeishuHandler(serverCtx),
			},
			{
				Method:  http.MethodPost,
				Path:    "/api/user/feishu/test-card",
				Handler: userhandler.SendFeishuTestCardHandler(serverCtx),
			},
		},
		rest.WithJwt(serverCtx.Config.Auth.AccessSecret),
	)
}
