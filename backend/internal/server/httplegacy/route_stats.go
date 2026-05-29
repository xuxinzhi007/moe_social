package httplegacy

import (
	"backend/internal/platform/moeimportcount"

	"backend/internal/platform/moewiring"
)

// KratosPureEnabled 是否纯 Kratos 生产（G=100% 路径）。
func KratosPureEnabled() bool {
	return moewiring.KratosPureEnabled()
}

// KratosHTTPFrontEnabled 是否启用 PK-4 生产前置（供进度口径）。
func KratosHTTPFrontEnabled() bool {
	return moewiring.KratosHTTPFrontEnabled()
}

// TotalHTTPRoutes Kratos 已注册 HTTP 路由分母（proto + swagger + intentional transport）。
func TotalHTTPRoutes() int {
	return nativeDomainRouteCount + swaggerRouteCount + PilotNativeCompatRoutes
}

// swaggerRouteCount 与 internal/server/http_docs.go 同步。
const swaggerRouteCount = 3

// PilotIntentionalCompatRoutes 有意保留 compat（OAuth 重定向 / SSE / WebSocket / multipart），不计入 D2 债务。
const (
	PilotIntentionalOAuthCompatRoutes = 2
	PilotIntentionalSSECompatRoutes   = 1
	PilotIntentionalWSCompatRoutes    = 4
)

const PilotIntentionalCompatRoutes = PilotIntentionalOAuthCompatRoutes +
	PilotIntentionalSSECompatRoutes + PilotIntentionalWSCompatRoutes

// PilotMigratableCompatRoutes 仍待迁入 proto HTTP 的 compat 路由数（= 活跃 compat − intentional）。
func PilotMigratableCompatRoutes() int {
	n := PilotNativeCompatRoutes - PilotIntentionalCompatRoutes
	if n < 0 {
		return 0
	}
	return n
}

// D2ProtoHTTPPercent D2：proto HTTP 占「proto + 可迁移 compat」比例（不含 intentional compat）。
func D2ProtoHTTPPercent() int {
	debt := PilotMigratableCompatRoutes()
	den := nativeDomainRouteCount + debt
	if den <= 0 {
		return 0
	}
	p := nativeDomainRouteCount * 100 / den
	if p > 100 {
		return 100
	}
	return p
}

const (
	d4CompatDebtClearedPct = 60
	d4DeadCompatPurgedPct  = 25
	d4Phase2BridgePct      = 40
	// d4DeadCompatPurged D4 Phase-0：zero-route compat 死代码已物理删除。
	d4DeadCompatPurged = true
)

// D4LegacyCleanupPercent D4：compat 债务清零 60% + 死代码删库 25% + Phase-2 bridge 退役 40%。
func D4LegacyCleanupPercent() int {
	debt := PilotMigratableCompatRoutes()
	if debt > 0 {
		const baseline = 34
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

// ProtoHTTPRouteCount 当前 proto HTTP 路由数（与 routes_native_gen 同步）。
func ProtoHTTPRouteCount() int {
	return nativeDomainRouteCount
}

// PilotNativeCompatRoutes 当前活跃 compat 路由数（仅 intentional transport）。
const PilotNativeCompatRoutes = PilotNativeUserCompatRoutes +
	PilotNativeChatCompatRoutes + PilotNativeAdminLegacyCompatRoutes

// TotalNativeHTTPRoutes 完整纯 Kratos 原生 HTTP 路由数（compat + 域原生生成）。
func TotalNativeHTTPRoutes() int {
	return PilotNativeCompatRoutes + nativeDomainRouteCount
}

// TotalBridgeHTTPRoutes 文档/Swagger bridge 路由数。
func TotalBridgeHTTPRoutes() int {
	return swaggerRouteCount
}

// RegisteredKratosHTTPRoutes 当前在 Kratos 注册的 HTTP 路由数（proto + swagger + intentional transport）。
func RegisteredKratosHTTPRoutes() int {
	return nativeDomainRouteCount + swaggerRouteCount + PilotNativeCompatRoutes
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
