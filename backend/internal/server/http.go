package server

import (
	"fmt"
	"strings"

	moeadmin "backend/internal/service/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func NewHTTPServer(addr string, deps HTTPServerDeps) (*khttp.Server, error) {
	if strings.TrimSpace(addr) == "" {
		return nil, fmt.Errorf("http address required")
	}
	srv := khttp.NewServer(
		khttp.Address(addr),
		khttp.Filter(requestLogFilter, corsFilter, jwtAuthFilter),
		khttp.ResponseEncoder(EnvelopeResponseEncoder),
		khttp.ErrorEncoder(EnvelopeErrorEncoder),
	)
	RegisterOpsHTTP(srv, deps.Ops.MoeAdmin)
	RegisterProtoHTTP(srv, deps.Proto)
	RegisterDocsHTTP(srv, deps.Docs)
	RegisterTransportHTTP(srv, deps.Transport)
	return srv, nil
}

func RegisterOpsHTTP(srv *khttp.Server, admin *moeadmin.AdminService) {
	if srv == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/health", healthHandler)
	r.GET("/migration", migrationHandler)
	r.GET("/kratos/v1/moe/runtimes", listRuntimesHandler(admin))
}
