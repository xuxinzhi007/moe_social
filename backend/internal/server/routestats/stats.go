package routestats

import (
	"backend/internal/platform/moeimportcount"
	"backend/internal/platform/moewiring"
	"backend/internal/server/transport"
)

// SwaggerRouteCount 与 internal/server/http_docs.go 同步。
const SwaggerRouteCount = 3

// KratosPureEnabled 是否纯 Kratos 生产（G=100% 路径）。
func KratosPureEnabled() bool {
	return moewiring.KratosPureEnabled()
}

// KratosHTTPFrontEnabled 是否启用 PK-4 生产前置（供进度口径）。
func KratosHTTPFrontEnabled() bool {
	return moewiring.KratosHTTPFrontEnabled()
}

// TransportHTTPRoutes OAuth + WebSocket + SSE（internal/server/transport）。
const TransportHTTPRoutes = transport.RouteCount

// TotalHTTPRoutes Kratos 已注册 HTTP 路由分母（proto + swagger + transport）。
func TotalHTTPRoutes() int {
	return protoHTTPRouteCount + SwaggerRouteCount + TransportHTTPRoutes
}

// PilotMigratableCompatRoutes 仍待迁入 proto HTTP 的路由数（当前应为 0）。
func PilotMigratableCompatRoutes() int {
	return 0
}

// D2ProtoHTTPPercent D2：proto HTTP 占全部可注册 HTTP 比例。
func D2ProtoHTTPPercent() int {
	den := protoHTTPRouteCount + PilotMigratableCompatRoutes()
	if den <= 0 {
		return 0
	}
	p := protoHTTPRouteCount * 100 / den
	if p > 100 {
		return 100
	}
	return p
}

const (
	d4CompatDebtClearedPct = 60
	d4DeadCompatPurgedPct  = 25
	d4Phase2BridgePct      = 40
	d4DeadCompatPurged       = true
)

// D4LegacyCleanupPercent D4：compat 债务清零 + 死代码删库 + Phase-2 bridge 退役。
func D4LegacyCleanupPercent() int {
	if PilotMigratableCompatRoutes() > 0 {
		const baseline = 34
		debt := PilotMigratableCompatRoutes()
		cleared := baseline - debt
		if cleared < 0 {
			return 0
		}
		return cleared * 50 / baseline
	}
	p := d4CompatDebtClearedPct
	if d4DeadCompatPurged {
		p += d4DeadCompatPurgedPct
	}
	p += moeimportcount.Phase2BridgeRetiredPercent() * d4Phase2BridgePct / 100
	if p > 100 {
		return 100
	}
	return p
}

// ProtoHTTPRouteCount 当前 proto HTTP 路由数（make gen 从 *_http.pb.go 统计）。
func ProtoHTTPRouteCount() int {
	return protoHTTPRouteCount
}

// TotalNativeHTTPRoutes proto + transport HTTP 路由数。
func TotalNativeHTTPRoutes() int {
	return protoHTTPRouteCount + TransportHTTPRoutes
}

// TotalBridgeHTTPRoutes Swagger 文档路由数。
func TotalBridgeHTTPRoutes() int {
	return SwaggerRouteCount
}

// RegisteredKratosHTTPRoutes 当前在 Kratos 注册的 HTTP 路由数。
func RegisteredKratosHTTPRoutes() int {
	return protoHTTPRouteCount + SwaggerRouteCount + TransportHTTPRoutes
}

// KratosGRPCManaged PK-7 gRPC 是否由 kratos.App 管理。
func KratosGRPCManaged() bool {
	return moewiring.KratosGRPCManaged()
}

// HTTPRouteCoveragePercent 路由覆盖率（0～100），供 kratosprogress 使用。
func HTTPRouteCoveragePercent() int {
	total := TotalHTTPRoutes()
	if total <= 0 {
		return 0
	}
	n := RegisteredKratosHTTPRoutes()
	p := n * 100 / total
	if p > 100 {
		return 100
	}
	return p
}

// HTTPNativeHandlerPercent 原生 handler 占比。
func HTTPNativeHandlerPercent() int {
	total := TotalHTTPRoutes()
	if total <= 0 {
		return 0
	}
	n := TotalNativeHTTPRoutes() * 100 / total
	if n > 100 {
		return 100
	}
	return n
}

// Compat 指标别名（/migration JSON 字段名保持不变）。
const (
	PilotNativeCompatRoutes       = TransportHTTPRoutes
	PilotIntentionalCompatRoutes  = TransportHTTPRoutes
	PilotIntentionalOAuthRoutes   = transport.OAuthRoutes
	PilotIntentionalSSERoutes     = transport.SSERoutes
	PilotIntentionalWSRoutes      = transport.WebSocketRoutes
)
