package server

import (
	hdoc "backend/internal/apilegacy/swaggerdoc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func RegisterDocsHTTP(srv *khttp.Server, deps DocsHTTPDeps) {
	if srv == nil || deps.ServiceContext == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/swagger", WrapNetHTTPHandler(hdoc.SwaggerUiHandler(deps.ServiceContext)))
	r.GET("/swagger/openapi.yaml", WrapNetHTTPHandler(hdoc.SwaggerOpenAPIHandler(deps.ServiceContext)))
	r.GET("/swagger/doc.json", WrapNetHTTPHandler(hdoc.SwaggerDocHandler(deps.ServiceContext)))
}
