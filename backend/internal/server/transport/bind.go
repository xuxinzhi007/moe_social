package transport

import khttp "github.com/go-kratos/kratos/v2/transport/http"

func bindRequest(ctx khttp.Context, v any) error {
	if ctx == nil {
		return nil
	}
	return ctx.Bind(v)
}
