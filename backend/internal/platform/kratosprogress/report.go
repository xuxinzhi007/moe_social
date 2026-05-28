// Package kratosprogress 迁移进度：percent=完整纯 Kratos 实现度；rollout_percent=传输/PK 铺轨。
package kratosprogress

import (
	"backend/api/moekratospilot"
	"backend/internal/platform/moewiring"
)

const (
	moeAdminGRPCMethods  = 11
	superLegacyRPCApprox = 189
)

// Report 迁移进度快照（/migration 与文档共用）。
type Report struct {
	// Percent 完整纯 Kratos 实现度（与 core-platform 对齐：原生 handler/service + kratos transport）。
	Percent int `json:"percent"`
	// RolloutPercent PK 传输层铺轨（路由挂 Kratos、纯 HTTP 监听、开关）；可达 100。
	RolloutPercent   int            `json:"rollout_percent"`
	PPercent         int            `json:"p_percent"` // 同 Percent，兼容旧客户端
	MigrationType    string         `json:"migration_type"`
	ProductionEntry  string         `json:"production_entry"`
	ExternalHTTPPort string         `json:"external_http_port"`
	Breakdown        map[string]int `json:"breakdown"`
	PilotDomains     []string       `json:"pilot_domains"`
	Notes            []string       `json:"notes"`
	Docs             string         `json:"docs"`
}

// Current 返回当前迁移快照。
func Current() Report {
	biz := 100
	contract := 100
	complete := completePureKratosPercent()
	rollout := rolloutPercent()
	migrationType := "kratos-hybrid-to-pure"
	if moewiring.KratosPureEnabled() {
		migrationType = "kratos-pure-transport"
	}
	if complete >= 90 {
		migrationType = "kratos-pure"
	}
	return Report{
		Percent:        complete,
		RolloutPercent: rollout,
		PPercent:       complete,
		MigrationType:  migrationType,
		ProductionEntry:  "moe-social",
		ExternalHTTPPort: "8888",
		Breakdown: map[string]int{
			"complete_pure_kratos_pct":     complete,
			"rollout_transport_pk_pct":     rollout,
			"http_native_handler_pct":      httpNativeHandlerPercent(),
			"http_bridge_handler_pct":      httpBridgeHandlerPercent(),
			"http_route_on_kratos_pct":     httpRouteCoveragePercent(),
			"http_transport_kratos_pct":    transportHTTPPurePercent(),
			"grpc_service_native_pct":      grpcMoeServiceLayerPercent(),
			"grpc_transport_kratos_pct":      grpcTransportNativePercent(),
			"grpc_lifecycle_managed_pct":     grpcLifecycleManagedPercent(),
			"http_bridge_cleared_pct":        bridgeClearedPercent(),
			"biz_gw_in_process":            biz,
			"contract_fs8_fs9":             contract,
			"kratos_pure_production":       boolPercent(moewiring.KratosPureEnabled()),
			"kratos_pk8_goctl_retired":     boolPercent(moewiring.KratosPK8GoctlRetired()),
		},
		PilotDomains: []string{
			"http.native: moekratospilot compat → internal/service",
			"http.bridge: wrapGoZeroHandler → api/internal/handler",
			"grpc.native: moegrpc (MoeAdmin); Super 仍 zrpc/logic",
		},
		Notes: []string{
			"percent = 48%http_native + 17%http_transport + 20%grpc_stack + 10%bridge_cleared + 5%pk8",
			"rollout_percent = PK 传输铺轨（可达100）",
			"终态 90%+：HTTP 全原生 + bridge≤swagger；Super 仍待 kratos grpc",
			"Rollback: kratos_pure_enabled=false",
		},
		Docs: "docs/dev/kratos-pure-complete-migration.md",
	}
}

// completePureKratosPercent 完整纯 Kratos（PK-10b：HTTP 原生 + 传输 + gRPC 铺轨 + 无 bridge）。
func completePureKratosPercent() int {
	httpN := httpNativeHandlerPercent()
	httpT := transportHTTPPurePercent()
	grpcStack := (grpcMoeServiceLayerPercent() + grpcLifecycleManagedPercent()) / 2
	bridgeFree := bridgeClearedPercent()
	pk8 := boolPercent(moewiring.KratosPK8GoctlRetired())
	p := (httpN*48 + httpT*17 + grpcStack*20 + bridgeFree*10 + pk8*5) / 100
	if p > 100 {
		return 100
	}
	return p
}

func bridgeClearedPercent() int {
	total := totalHTTPRoutes()
	if total <= 0 {
		return 0
	}
	bridge := moekratospilot.TotalBridgeHTTPRoutes()
	left := (total - bridge) * 100 / total
	if left < 0 {
		return 0
	}
	if left > 100 {
		return 100
	}
	return left
}

// rolloutPercent PK/传输铺轨进度（契约、biz、路由挂 Kratos、纯 HTTP 监听）。
func rolloutPercent() int {
	biz := 100
	contract := 100
	routeCov := httpRouteCoveragePercent()
	transport := transportRolloutPercent()
	p := (biz*20 + contract*20 + routeCov*30 + transport*30) / 100
	if p > 100 {
		return 100
	}
	return p
}

func httpNativeHandlerPercent() int {
	p := moekratospilot.HTTPNativeHandlerPercent()
	// PK-10b：仅 swagger 留在 bridge 时视为 HTTP 层完成。
	if moekratospilot.TotalBridgeHTTPRoutes() <= 2 && p >= 95 {
		return 100
	}
	return p
}

func totalHTTPRoutes() int {
	return moekratospilot.TotalGoZeroRoutes
}

func registeredHTTPRoutes() int {
	return moekratospilot.RegisteredKratosHTTPRoutes()
}

func httpBridgeHandlerPercent() int {
	if totalHTTPRoutes() <= 0 {
		return 0
	}
	n := moekratospilot.TotalBridgeHTTPRoutes() * 100 / totalHTTPRoutes()
	if n < 0 {
		return 0
	}
	return n
}

func grpcMoeServiceLayerPercent() int {
	den := moeAdminGRPCMethods + superLegacyRPCApprox
	if den <= 0 {
		return 0
	}
	n := moeAdminGRPCMethods * 100 / den
	if n > 100 {
		return 100
	}
	return n
}

// transportHTTPPurePercent Kratos HTTP 对外且未启 go-zero rest（PK-9）。
func transportHTTPPurePercent() int {
	if moewiring.KratosPureHTTPWithoutLegacy() {
		return 100
	}
	if moewiring.KratosHTTPFrontEnabled() {
		return 50
	}
	return 0
}

// grpcTransportNativePercent 完整纯 Kratos：须 kratos/transport/grpc 替代 zrpc（当前 Super 仍为 zrpc → 0）。
func grpcTransportNativePercent() int {
	// 待 Super 迁 internal/server + kratos grpc 后再计分；MoeAdmin 挂在 zrpc.Server 上不计入。
	return 0
}

func grpcLifecycleManagedPercent() int {
	if moewiring.KratosGRPCManaged() || moewiring.KratosPureEnabled() {
		return 100
	}
	return 0
}

func transportRolloutPercent() int {
	if moewiring.KratosPureHTTPWithoutLegacy() {
		return 100
	}
	return (transportHTTPRolloutPercent()*70 + grpcLifecycleManagedPercent()*30) / 100
}

func transportHTTPRolloutPercent() int {
	if moewiring.KratosPureHTTPWithoutLegacy() {
		return 100
	}
	if moewiring.KratosHTTPFrontEnabled() {
		return 85
	}
	if httpRouteCoveragePercent() >= 95 {
		return 75
	}
	return 55
}

func httpRouteCoveragePercent() int {
	return moekratospilot.HTTPRouteCoveragePercent()
}

func boolPercent(ok bool) int {
	if ok {
		return 100
	}
	return 0
}
