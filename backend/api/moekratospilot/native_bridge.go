package moekratospilot

import (
	"net/http"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// wrapNativeHTTP 域原生 Kratos 注册：直挂 Kratos 路由表，逻辑仍经 api/internal/logic（PK-10 再迁 internal/service）。
func wrapNativeHTTP(h http.HandlerFunc) func(khttp.Context) error {
	if h == nil {
		return func(khttp.Context) error { return nil }
	}
	return func(ctx khttp.Context) error {
		h(ctx.Response(), ctx.Request())
		return nil
	}
}
