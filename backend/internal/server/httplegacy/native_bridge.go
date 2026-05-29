package httplegacy

import (
	"net/http"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// wrapNativeHTTP PK-12 生产路径：Kratos HTTP 直挂路由，经 goctl handler → *gw/biz（与 co 薄 service 等价）。
func wrapNativeHTTP(h http.HandlerFunc) func(khttp.Context) error {
	if h == nil {
		return func(khttp.Context) error { return nil }
	}
	return func(ctx khttp.Context) error {
		h(ctx.Response(), ctx.Request())
		return nil
	}
}
