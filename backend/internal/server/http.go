package server

import (
	"fmt"
	"net/http"
	"strings"

	"backend/internal/server/transport"
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

func WrapNetHTTPHandler(h http.HandlerFunc) func(khttp.Context) error {
	if h == nil {
		return func(khttp.Context) error { return nil }
	}
	return func(ctx khttp.Context) error {
		h(ctx.Response(), ctx.Request())
		return nil
	}
}

func RegisterTransportHTTP(srv *khttp.Server, deps transport.Deps) {
	if srv == nil || !deps.Valid() {
		return
	}
	transport.RegisterHTTP(srv, deps)
}
