package server

import (
	"fmt"
	"strings"

	"backend/internal/server/httplegacy"
	moeadmin "backend/internal/service/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// NewHTTPServer 创建并注册全部 HTTP 路由（S2：唯一装配入口）。
func NewHTTPServer(addr string, deps httplegacy.PilotDeps) (*khttp.Server, error) {
	if strings.TrimSpace(addr) == "" {
		return nil, fmt.Errorf("http address required")
	}
	srv := khttp.NewServer(
		khttp.Address(addr),
		khttp.Filter(corsFilter),
		khttp.ResponseEncoder(EnvelopeResponseEncoder),
		khttp.ErrorEncoder(EnvelopeErrorEncoder),
	)
	RegisterOpsHTTP(srv, deps.MoeAdmin)
	RegisterProtoHTTP(srv, ProtoHTTPDepsFromPilot(deps))
	RegisterCompatHTTP(srv, deps)
	return srv, nil
}

// RegisterOpsHTTP 注册运维 HTTP（/health、/migration 等）。
func RegisterOpsHTTP(srv *khttp.Server, admin *moeadmin.AdminService) {
	if srv == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/health", healthHandler)
	r.GET("/migration", migrationHandler)
	r.GET("/kratos/v1/moe/runtimes", listRuntimesHandler(admin))
}
