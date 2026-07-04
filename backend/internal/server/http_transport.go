package server

import (
	"backend/internal/server/transport"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func RegisterTransportHTTP(srv *khttp.Server, deps transport.Deps) {
	if srv == nil || !deps.Valid() {
		return
	}
	transport.RegisterHTTP(srv, deps)
}
