package server

import (
	hdoc "backend/internal/server/swaggerdoc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func RegisterDocsHTTP(srv *khttp.Server, deps DocsHTTPDeps) {
	if srv == nil {
		return
	}
	r := srv.Route("/")
	if deps.UIHandler != nil {
		r.GET("/swagger", WrapNetHTTPHandler(deps.UIHandler))
	}
	if deps.OpenAPIHandler != nil {
		r.GET("/swagger/openapi.yaml", WrapNetHTTPHandler(deps.OpenAPIHandler))
	}
	if deps.JSONHandler != nil {
		r.GET("/swagger/doc.json", WrapNetHTTPHandler(deps.JSONHandler))
	}
}

func DefaultDocsHTTPDeps() DocsHTTPDeps {
	return DocsHTTPDeps{
		UIHandler:      hdoc.SwaggerUiHandler(),
		OpenAPIHandler: hdoc.SwaggerOpenAPIHandler(),
		JSONHandler:    hdoc.SwaggerDocHandler(),
	}
}
