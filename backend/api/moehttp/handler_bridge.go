package moehttp

import (
	"net/http"

	"backend/api/internal/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// wrapGoZeroHandler 将 go-zero 生成的 http.HandlerFunc 适配为 Kratos HTTP。
func wrapGoZeroHandler(h http.HandlerFunc) func(khttp.Context) error {
	if h == nil {
		return func(khttp.Context) error { return nil }
	}
	return func(ctx khttp.Context) error {
		h(ctx.Response(), ctx.Request())
		return nil
	}
}

// RegisterGoZeroHTTPHandlers 兼容旧名（仅 bridge 路由，如 swagger）。
func RegisterGoZeroHTTPHandlers(srv *khttp.Server, svc *svc.ServiceContext) {
	RegisterBridgeHTTPHandlers(srv, svc)
}
