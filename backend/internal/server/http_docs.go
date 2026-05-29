package server

import (
	hdoc "backend/internal/apilegacy/swaggerdoc"
	"backend/internal/platform/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterDocsHTTP 注册 Swagger / OpenAPI 文档路由。
func RegisterDocsHTTP(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/swagger", WrapNetHTTPHandler(hdoc.SwaggerUiHandler(svc)))
	r.GET("/swagger/openapi.yaml", WrapNetHTTPHandler(hdoc.SwaggerOpenAPIHandler(svc)))
	r.GET("/swagger/doc.json", WrapNetHTTPHandler(hdoc.SwaggerDocHandler(svc)))
}
