package platformhttp

import (
	"context"
	"net/http"
	"reflect"

	"github.com/go-kratos/kratos/v2/transport"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func httpFromContext(ctx context.Context) (http.ResponseWriter, *http.Request, bool) {
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return nil, nil, false
	}
	tr, ok := transport.FromServerContext(ctx)
	if !ok {
		return nil, req, false
	}
	rv := reflect.ValueOf(tr)
	if rv.Kind() == reflect.Pointer {
		rv = rv.Elem()
	}
	f := rv.FieldByName("response")
	if !f.IsValid() || f.IsNil() {
		return nil, req, false
	}
	w, _ := f.Interface().(http.ResponseWriter)
	return w, req, w != nil
}
