// Package handler 中本文件为手工维护。
// internal/handler/routes.go 由 goctl 根据 super.api 生成，重新执行 goctl 会覆盖该文件；
// LLM「终端同款」raw 转发路由放在此处，并在 super.go 里 RegisterHandlers 之后调用 RegisterLlmRawRoutes。

package handler

import (
	"net/http"

	llm "backend/api/internal/handler/llm"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

// RegisterLlmRawRoutes 注册原样转发 Ollama 的 HTTP 路由（与 Flutter LlmEndpointConfig 一致）。
func RegisterLlmRawRoutes(server *rest.Server, serverCtx *svc.ServiceContext) {
	server.AddRoutes(
		[]rest.Route{
			{
				Method:  http.MethodGet,
				Path:    "/api/llm/models/raw",
				Handler: llm.ModelsRawHandler(serverCtx),
			},
			{
				Method:  http.MethodGet,
				Path:    "/api/llm/config",
				Handler: llm.ConfigHandler(serverCtx),
			},
			{
				Method:  http.MethodPost,
				Path:    "/api/llm/chat/raw",
				Handler: llm.ChatRawHandler(serverCtx),
			},
			{
				Method:  http.MethodPost,
				Path:    "/api/llm/show/raw",
				Handler: llm.ShowRawHandler(serverCtx),
			},
		},
	)
}
