package routestats

import "backend/internal/server/transport"

// SwaggerRouteCount 与 internal/server/http_docs.go 同步。
const SwaggerRouteCount = 3

// TransportHTTPRoutes OAuth + WebSocket + SSE（internal/server/transport）。
const TransportHTTPRoutes = transport.RouteCount

// ProtoHTTPRouteCount 当前 proto HTTP 路由数（make gen 从 *_http.pb.go 统计）。
func ProtoHTTPRouteCount() int {
	return protoHTTPRouteCount
}

// TotalHTTPRoutes Kratos 已注册 HTTP 路由分母（proto + swagger + transport）。
func TotalHTTPRoutes() int {
	return protoHTTPRouteCount + SwaggerRouteCount + TransportHTTPRoutes
}
