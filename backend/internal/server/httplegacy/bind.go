package httplegacy

import khttp "github.com/go-kratos/kratos/v2/transport/http"

// bindRequest 解析 path/query/form/body（P5-D 替代 go-zero httpx.Parse）。
func bindRequest(ctx khttp.Context, v any) error {
	if ctx == nil {
		return nil
	}
	return ctx.Bind(v)
}
