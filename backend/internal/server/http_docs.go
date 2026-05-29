package server

import (
	hdoc "backend/internal/apilegacy/swaggerdoc"
	"backend/internal/platform/svc"
	"backend/internal/server/httplegacy"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// swaggerRouteCount OpenAPI / Swagger UI 静态路由数（非 compat 债务）。
const swaggerRouteCount = 3

// RegisterDocsHTTP 注册 Swagger / OpenAPI 文档路由（Kratos 官方 HTTP 之外的静态 bridge）。
func RegisterDocsHTTP(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/swagger", httplegacy.WrapNetHTTPHandler(hdoc.SwaggerUiHandler(svc)))
	r.GET("/swagger/openapi.yaml", httplegacy.WrapNetHTTPHandler(hdoc.SwaggerOpenAPIHandler(svc)))
	r.GET("/swagger/doc.json", httplegacy.WrapNetHTTPHandler(hdoc.SwaggerDocHandler(svc)))
}
