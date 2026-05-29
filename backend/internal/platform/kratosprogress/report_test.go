package kratosprogress

import (
	"os"
	"path/filepath"
	"testing"

	"backend/internal/platform/moewiring"
)

func TestMain(m *testing.M) {
	for _, root := range []string{".", "../..", "../../.."} {
		if _, err := os.Stat(filepath.Join(root, "config", "config.yaml")); err == nil {
			_ = os.Chdir(root)
			break
		}
	}
	os.Exit(m.Run())
}

func TestRolloutPercentAtLeast80(t *testing.T) {
	if !moewiring.KratosPureEnabled() {
		t.Fatal("set moe.kratos_pure_enabled: true in backend/config/config.yaml")
	}
	rep := Current()
	if rep.RolloutPercent < 80 {
		t.Fatalf("expected rollout_percent >= 80, got %d", rep.RolloutPercent)
	}
}

func TestRolloutPercentAtLeast100WhenPure(t *testing.T) {
	if !moewiring.KratosPureEnabled() {
		t.Fatal("set moe.kratos_pure_enabled: true in backend/config/config.yaml")
	}
	rep := Current()
	if rep.RolloutPercent < 100 {
		t.Fatalf("expected rollout_percent >= 100, got %d", rep.RolloutPercent)
	}
}

func TestOverallMigrationAtLeast50(t *testing.T) {
	rep := Current()
	if rep.Percent < 50 {
		t.Fatalf("expected overall percent >= 50, got %d breakdown=%v",
			rep.Percent, rep.Breakdown)
	}
	if rep.PPercent != rep.Percent {
		t.Fatalf("p_percent should match percent, got %d vs %d", rep.PPercent, rep.Percent)
	}
}

func TestD2ProtoHTTPAtLeast100(t *testing.T) {
	rep := Current()
	if rep.D2ProtoHTTPPercent < 100 {
		t.Fatalf("expected d2_proto_http_pct == 100, got %d breakdown=%v",
			rep.D2ProtoHTTPPercent, rep.Breakdown)
	}
	if rep.Breakdown["compat_routes_migratable"] != 0 {
		t.Fatalf("expected compat_routes_migratable == 0, got %d", rep.Breakdown["compat_routes_migratable"])
	}
}

func TestD4LegacyCleanupAtLeast100(t *testing.T) {
	rep := Current()
	if rep.Breakdown["biz_moe_import_files_left"] > 0 || rep.Breakdown["apilegacy_moe_import_files_left"] > 0 {
		t.Skip("Phase-2 bridge migration in progress")
	}
	if rep.D4LegacyCleanupPercent < 100 {
		t.Fatalf("expected d4_legacy_cleanup_pct == 100, got %d breakdown=%v",
			rep.D4LegacyCleanupPercent, rep.Breakdown)
	}
}

func TestOverallMigrationAtLeast100(t *testing.T) {
	rep := Current()
	if rep.Breakdown["biz_moe_import_files_left"] > 0 || rep.Breakdown["apilegacy_moe_import_files_left"] > 0 {
		t.Skip("Phase-2 bridge migration in progress")
	}
	if rep.Percent < 100 {
		t.Fatalf("expected overall percent == 100, got %d (d2=%d d4=%d)",
			rep.Percent, rep.D2ProtoHTTPPercent, rep.D4LegacyCleanupPercent)
	}
}

func TestPhase2BreakdownKeys(t *testing.T) {
	rep := Current()
	for _, k := range []string{
		"d4_phase2_bridge_pct",
		"biz_moe_import_files_left",
		"apilegacy_moe_import_files_left",
	} {
		if _, ok := rep.Breakdown[k]; !ok {
			t.Fatalf("missing breakdown key %q", k)
		}
	}
}

func TestPhase2BridgeRetiredWhenComplete(t *testing.T) {
	if BizMoeImportFileCount() > 0 || ApilegacyMoeImportFileCount() > 0 {
		t.Skip("Phase-2 bridge migration in progress")
	}
	if got := Phase2BridgeRetiredPercent(); got != 100 {
		t.Fatalf("expected phase2 bridge retired 100 when no moe imports remain, got %d", got)
	}
	rep := Current()
	if rep.Breakdown["d4_phase2_bridge_pct"] != 100 {
		t.Fatalf("expected d4_phase2_bridge_pct == 100, got %d", rep.Breakdown["d4_phase2_bridge_pct"])
	}
}

func TestOverallBelowRolloutWhileD2Incomplete(t *testing.T) {
	rep := Current()
	if rep.RolloutPercent >= 100 && rep.D2ProtoHTTPPercent < 100 && rep.Percent > rep.RolloutPercent {
		t.Fatalf("overall (%d) should not exceed rollout (%d) while D2 incomplete",
			rep.Percent, rep.RolloutPercent)
	}
}

func TestOverallNot100UntilMigratableCompatZero(t *testing.T) {
	rep := Current()
	if rep.Breakdown["compat_routes_migratable"] > 0 && rep.Percent >= 100 {
		t.Fatalf("percent should be <100 while migratable compat remains: percent=%d migratable=%d",
			rep.Percent, rep.Breakdown["compat_routes_migratable"])
	}
}

func TestD2BreakdownKeys(t *testing.T) {
	rep := Current()
	for _, k := range []string{
		"d2_proto_http_pct",
		"d4_legacy_cleanup_pct",
		"proto_http_routes",
		"compat_routes_active",
		"compat_routes_migratable",
		"compat_routes_intentional",
		"complete_pure_kratos_pct",
		"rollout_transport_pk_pct",
	} {
		if _, ok := rep.Breakdown[k]; !ok {
			t.Fatalf("missing breakdown key %q", k)
		}
	}
}

func TestTransportBreakdown100WhenPure(t *testing.T) {
	if !moewiring.KratosPureEnabled() {
		t.Fatal("set moe.kratos_pure_enabled: true")
	}
	rep := Current()
	for _, k := range []string{
		"http_native_handler_pct",
		"http_transport_kratos_pct",
		"grpc_service_native_pct",
		"grpc_transport_kratos_pct",
		"grpc_lifecycle_managed_pct",
		"kratos_pure_production",
	} {
		if rep.Breakdown[k] != 100 {
			t.Fatalf("PK-12: %s want 100, got %d", k, rep.Breakdown[k])
		}
	}
}

func TestCompletePureBreakdownKeys(t *testing.T) {
	rep := Current()
	for _, k := range []string{
		"http_native_handler_pct",
		"http_bridge_handler_pct",
		"grpc_transport_kratos_pct",
		"complete_pure_kratos_pct",
		"legacy_logic_retired_pct",
		"legacy_logic_files_left",
	} {
		if _, ok := rep.Breakdown[k]; !ok {
			t.Fatalf("missing breakdown key %q", k)
		}
	}
	if !moewiring.KratosSuperGRPCNative() {
		t.Fatal("set moe.kratos_super_grpc_native: true for PK-11")
	}
	if rep.Breakdown["grpc_transport_kratos_pct"] != 100 {
		t.Fatalf("PK-11: grpc_transport_kratos_pct want 100, got %d",
			rep.Breakdown["grpc_transport_kratos_pct"])
	}
}
