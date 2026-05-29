package moehttp

import (
	"net/http"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// wrapNetHTTPHandler 将标准 net/http HandlerFunc 适配为 Kratos HTTP。
func wrapNetHTTPHandler(h http.HandlerFunc) func(khttp.Context) error {
	if h == nil {
		return func(khttp.Context) error { return nil }
	}
	return func(ctx khttp.Context) error {
		h(ctx.Response(), ctx.Request())
		return nil
	}
}
