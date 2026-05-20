// 用户记忆展示 API（非 goctl 生成，避免 routes.go 被覆盖时丢失）。

package handler

import (
	"net/http"

	"backend/api/internal/handler/user"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

func RegisterMemoryDisplayRoutes(server *rest.Server, serverCtx *svc.ServiceContext) {
	server.AddRoutes(
		[]rest.Route{
			{
				Method:  http.MethodGet,
				Path:    "/api/user/:user_id/memories/display",
				Handler: user.GetUserMemoriesDisplayHandler(serverCtx),
			},
			{
				Method:  http.MethodGet,
				Path:    "/api/user/:user_id/memories/search",
				Handler: user.SearchUserMemoriesHandler(serverCtx),
			},
			{
				Method:  http.MethodPost,
				Path:    "/api/user/:user_id/memories/reindex",
				Handler: user.RebuildUserMemoryEmbeddingsHandler(serverCtx),
			},
		},
	)
}
