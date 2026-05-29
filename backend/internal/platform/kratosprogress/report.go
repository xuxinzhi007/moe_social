// Package kratosprogress 迁移进度（三套口径 SSOT，勿混用）：
//   - rollout_percent：P0–P5 传输铺轨
//   - d2_proto_http_pct：D2 compat→proto HTTP（不含 intentional compat）
//   - d4_legacy_cleanup_pct：D4 遗留层清理
//   - percent：综合完成度 = (d2*50 + d4*50)/100
package kratosprogress

import (
	"backend/internal/server/routestats"
	"backend/internal/platform/moewiring"
)

const (
	moeAdminGRPCMethods  = 11
	superLegacyRPCApprox = 189
)

// Report 迁移进度快照（/migration 与文档共用）。
type Report struct {
	// Percent 综合完成度（D2 50% + D4 50%）；勿与 rollout_percent 混用。
	Percent int `json:"percent"`
	// RolloutPercent P0–P5 传输铺轨（路由挂 Kratos、零 go-zero）；可达 100。
	RolloutPercent int `json:"rollout_percent"`
	// D2ProtoHTTPPercent D2：proto HTTP / (proto + 可迁移 compat)。
	D2ProtoHTTPPercent int `json:"d2_proto_http_pct"`
	// D4LegacyCleanupPercent D4：遗留层清理进度。
	D4LegacyCleanupPercent int `json:"d4_legacy_cleanup_pct"`
	PPercent               int `json:"p_percent"` // 同 Percent，兼容旧客户端
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
	rollout := rolloutPercent()
	d2 := routestats.D2ProtoHTTPPercent()
	d4 := routestats.D4LegacyCleanupPercent()
	complete := overallMigrationPercent(d2, d4)
	migrationType := "kratos-hybrid-to-pure"
	if moewiring.KratosPureEnabled() {
		migrationType = "kratos-pure-transport"
	}
	if complete >= 90 {
		migrationType = "kratos-pure"
	}
	return Report{
		Percent:                complete,
		RolloutPercent:         rollout,
		D2ProtoHTTPPercent:     d2,
		D4LegacyCleanupPercent: d4,
		PPercent:               complete,
		MigrationType:          migrationType,
		ProductionEntry:        "moe-social",
		ExternalHTTPPort:       "8888",
		Breakdown: map[string]int{
			"complete_pure_kratos_pct":     complete,
			"rollout_transport_pk_pct":       rollout,
			"d2_proto_http_pct":              d2,
			"d4_legacy_cleanup_pct":          d4,
			"d4_phase2_bridge_pct":           Phase2BridgeRetiredPercent(),
			"d4_phase4_rpc_pb_retired_pct":   RpcMoePbRetiredPercent(),
			"biz_moe_import_files_left":      BizMoeImportFileCount(),
			"apilegacy_moe_import_files_left": ApilegacyMoeImportFileCount(),
			"runtime_moe_pb_import_files_left": RuntimeMoePbImportFileCount(),
			"proto_http_routes":              routestats.ProtoHTTPRouteCount(),
			"compat_routes_active":           routestats.PilotNativeCompatRoutes,
			"compat_routes_migratable":       routestats.PilotMigratableCompatRoutes(),
			"compat_routes_intentional":      routestats.PilotIntentionalCompatRoutes,
			"http_native_handler_pct":        httpNativeHandlerPercent(),
			"http_bridge_handler_pct":        httpBridgeHandlerPercent(),
			"http_route_on_kratos_pct":       httpRouteCoveragePercent(),
			"http_transport_kratos_pct":      transportHTTPPurePercent(),
			"grpc_service_native_pct":        grpcMoeServiceLayerPercent(),
			"grpc_transport_kratos_pct":      grpcTransportNativePercent(),
			"grpc_lifecycle_managed_pct":     grpcLifecycleManagedPercent(),
			"http_bridge_cleared_pct":        bridgeClearedPercent(),
			"legacy_logic_retired_pct":       LegacyLogicRetiredPercent(),
			"legacy_logic_files_left":        LegacyLogicFileCount(),
			"biz_gw_in_process":              biz,
			"contract_fs8_fs9":               contract,
			"kratos_pure_production":         boolPercent(moewiring.KratosPureEnabled()),
			"kratos_pk8_goctl_retired":       boolPercent(moewiring.KratosPK8GoctlRetired()),
			"super_grpc_retired_pct":         P5SuperRuntimePercent(),
			"p5_super_runtime_pct":             P5SuperRuntimePercent(),
			"rpc_logic_retired_pct":          RPCLegacyLogicRetiredPercent(),
			"rpc_logic_files_left":           RPCLegacyLogicFileCount(),
		},
		PilotDomains: []string{
			"http: kratos transport/http :8888 (proto + intentional compat → biz)",
			"http.bridge: swagger (3 routes)",
			"grpc: kratos transport/grpc :8080 (12 domain + MoeAdmin)",
		},
		Notes: []string{
			"三套口径：rollout_percent=P0-P5传输 | d2_proto_http_pct=D2契约 | d4_legacy_cleanup_pct=D4清库",
			"percent = (d2_proto_http_pct*50 + d4_legacy_cleanup_pct*50) / 100",
			"intentional compat = OAuth(2)+SSE(1)+WS(4)+multipart(4)，不计入 D2 分母",
			"production: make moe-social — kratos HTTP :8888 + kratos grpc :8080",
		},
		Docs: "docs/dev/kratos-migration-status.md",
	}
}

func overallMigrationPercent(d2, d4 int) int {
	p := (d2*50 + d4*50) / 100
	if p > 100 {
		return 100
	}
	if p < 0 {
		return 0
	}
	return p
}

// completePureKratosPercent 完整纯 Kratos：传输栈 + legacy logic 退役进度。
func completePureKratosPercent() int {
	transport := transportStackPercent()
	logicRet := LegacyLogicRetiredPercent()
	p := (transport*85 + logicRet*15) / 100
	if p > 100 {
		return 100
	}
	return p
}

func transportStackPercent() int {
	httpN := httpNativeHandlerPercent()
	httpT := transportHTTPPurePercent()
	grpcSvc := grpcMoeServiceLayerPercent()
	grpcT := grpcTransportNativePercent()
	if moewiring.KratosPureEnabled() {
		p := (httpN*40 + grpcSvc*30 + httpT*20 + grpcT*10) / 100
		if p > 100 {
			return 100
		}
		return p
	}
	grpcStack := (grpcSvc + grpcLifecycleManagedPercent()) / 2
	bridgeFree := bridgeClearedPercent()
	pk8 := boolPercent(moewiring.KratosPK8GoctlRetired())
	p := (httpN*48 + httpT*17 + grpcStack*20 + bridgeFree*10 + pk8*5) / 100
	if moewiring.KratosSuperGRPCNative() {
		p += 10
	}
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
	bridge := routestats.TotalBridgeHTTPRoutes()
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
	p := routestats.HTTPNativeHandlerPercent()
	// PK-10b：仅 swagger 三件套留在 bridge 时视为 HTTP 层完成。
	if routestats.TotalBridgeHTTPRoutes() <= 3 && p >= 95 {
		return 100
	}
	return p
}

func totalHTTPRoutes() int {
	n := routestats.TotalHTTPRoutes()
	if n <= 0 {
		return 268
	}
	return n
}

func registeredHTTPRoutes() int {
	return routestats.RegisteredKratosHTTPRoutes()
}

func httpBridgeHandlerPercent() int {
	if totalHTTPRoutes() <= 0 {
		return 0
	}
	n := routestats.TotalBridgeHTTPRoutes() * 100 / totalHTTPRoutes()
	if n < 0 {
		return 0
	}
	return n
}

func grpcMoeServiceLayerPercent() int {
	// P5-A：Super 退役后仅暴露域 gRPC（12/12）+ MoeAdmin。
	if moewiring.SuperGrpcRetired() {
		return 100
	}
	// PK-11/12：纯 Kratos 生产下 Super+MoeAdmin 均由 kratos/transport/grpc 暴露。
	if moewiring.KratosPureEnabled() && moewiring.KratosSuperGRPCNative() {
		return 100
	}
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

// grpcTransportNativePercent PK-11：Super 使用 kratos/transport/grpc（非 zrpc）。
func grpcTransportNativePercent() int {
	if moewiring.KratosSuperGRPCNative() {
		return 100
	}
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
	return routestats.HTTPRouteCoveragePercent()
}

func boolPercent(ok bool) int {
	if ok {
		return 100
	}
	return 0
}
