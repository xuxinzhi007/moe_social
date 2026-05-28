package moekratospilot

import "backend/internal/platform/moewiring"

// KratosPureEnabled 是否纯 Kratos 生产（G=100% 路径）。
func KratosPureEnabled() bool {
	return moewiring.KratosPureEnabled()
}

// KratosHTTPFrontEnabled 是否启用 PK-4 生产前置（供进度口径）。
func KratosHTTPFrontEnabled() bool {
	return moewiring.KratosHTTPFrontEnabled()
}

// TotalGoZeroRoutes 与 handler/routes.go 中 Path 条数对齐（goctl 生成后需 sync gen）。
const TotalGoZeroRoutes = 268

// PilotNativeCompatRoutes internal/service 直挂（admin_compat / insights / vip / llm）。
const PilotNativeCompatRoutes = 13

// TotalNativeHTTPRoutes 完整纯 Kratos 原生 HTTP 路由数（compat + 域原生生成）。
func TotalNativeHTTPRoutes() int {
	return PilotNativeCompatRoutes + nativeDomainRouteCount
}

// TotalBridgeHTTPRoutes 仍经 wrapGoZeroHandler 的遗留路由数。
func TotalBridgeHTTPRoutes() int {
	return bridgeRouteCount
}

// RegisteredKratosHTTPRoutes 当前在 Kratos 注册的 HTTP 路由数（native + bridge + compat）。
func RegisteredKratosHTTPRoutes() int {
	return nativeDomainRouteCount + bridgeRouteCount + PilotNativeCompatRoutes
}

// KratosGRPCManaged PK-7 gRPC 是否由 kratos.App 管理。
func KratosGRPCManaged() bool {
	return moewiring.KratosGRPCManaged()
}

// HTTPRouteCoveragePercent 路由覆盖率（0～100），供 kratosprogress 使用。
func HTTPRouteCoveragePercent() int {
	if TotalGoZeroRoutes <= 0 {
		return 0
	}
	n := RegisteredKratosHTTPRoutes()
	p := n * 100 / TotalGoZeroRoutes
	if p > 100 {
		return 100
	}
	return p
}

// HTTPNativeHandlerPercent 原生 handler 占比。
func HTTPNativeHandlerPercent() int {
	if TotalGoZeroRoutes <= 0 {
		return 0
	}
	n := TotalNativeHTTPRoutes() * 100 / TotalGoZeroRoutes
	if n > 100 {
		return 100
	}
	return n
}
