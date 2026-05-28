package moehttp

import "backend/internal/platform/moewiring"

// KratosPureEnabled 是否纯 Kratos 生产（G=100% 路径）。
func KratosPureEnabled() bool {
	return moewiring.KratosPureEnabled()
}

// KratosHTTPFrontEnabled 是否启用 PK-4 生产前置（供进度口径）。
func KratosHTTPFrontEnabled() bool {
	return moewiring.KratosHTTPFrontEnabled()
}

// TotalGoZeroRoutes Kratos 已注册 HTTP 路由分母（native + bridge + compat；与 goctl routes 268 条中未挂 Kratos 的 3 条遗留区分）。
func TotalGoZeroRoutes() int {
	return nativeDomainRouteCount + bridgeRouteCount + PilotNativeCompatRoutes
}

// PilotNativeCompatRoutes internal/service 直挂（admin / insights / vip / llm / landing）。
const PilotNativeCompatRoutes = 13 + PilotNativeLandingCompatRoutes

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
	total := TotalGoZeroRoutes()
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
	total := TotalGoZeroRoutes()
	if total <= 0 {
		return 0
	}
	n := TotalNativeHTTPRoutes() * 100 / total
	if n > 100 {
		return 100
	}
	return n
}
