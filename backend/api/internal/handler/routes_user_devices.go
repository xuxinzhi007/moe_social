// 用户设备 API（非 goctl 生成，避免 routes.go 被覆盖时丢失）。

package handler

import (
	"net/http"

	"backend/api/internal/handler/user"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

func RegisterUserDeviceRoutes(server *rest.Server, serverCtx *svc.ServiceContext) {
	server.AddRoutes(
		[]rest.Route{
			{
				Method:  http.MethodPost,
				Path:    "/api/user/:user_id/devices/sync",
				Handler: user.SyncUserDeviceHandler(serverCtx),
			},
			{
				Method:  http.MethodGet,
				Path:    "/api/user/:user_id/devices",
				Handler: user.ListUserDevicesHandler(serverCtx),
			},
		},
	)
}
