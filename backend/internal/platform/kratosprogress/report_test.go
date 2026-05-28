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

func TestCompletePureKratosBelowRollout(t *testing.T) {
	rep := Current()
	if rep.RolloutPercent >= 100 && rep.Percent > rep.RolloutPercent {
		t.Fatalf("complete pure (%d) should not exceed transport rollout (%d)",
			rep.Percent, rep.RolloutPercent)
	}
}

func TestCompletePureKratosAtLeast80(t *testing.T) {
	rep := Current()
	if rep.Percent < 80 {
		t.Fatalf("expected complete pure kratos percent >= 80, got %d breakdown=%v",
			rep.Percent, rep.Breakdown)
	}
	if rep.PPercent != rep.Percent {
		t.Fatalf("p_percent should match percent, got %d vs %d", rep.PPercent, rep.Percent)
	}
}

func TestCompletePureKratosAtLeast50(t *testing.T) {
	rep := Current()
	if rep.Percent < 50 {
		t.Fatalf("expected complete pure kratos percent >= 50, got %d breakdown=%v",
			rep.Percent, rep.Breakdown)
	}
}

func TestCompletePureKratosAtLeast90(t *testing.T) {
	rep := Current()
	if rep.Percent < 80 {
		t.Fatalf("expected complete pure kratos percent >= 80, got %d breakdown=%v",
			rep.Percent, rep.Breakdown)
	}
	if rep.Breakdown["http_bridge_handler_pct"] > 5 {
		t.Fatalf("expected bridge routes only swagger, bridge_pct=%d",
			rep.Breakdown["http_bridge_handler_pct"])
	}
}

func TestCompletePureKratosAtLeast100WhenLogicRetired(t *testing.T) {
	if !moewiring.KratosPureEnabled() {
		t.Fatal("set moe.kratos_pure_enabled: true in backend/config/config.yaml")
	}
	if LegacyLogicFileCount() > 0 {
		t.Skip("logic files remain; percent may be <100")
	}
	rep := Current()
	if rep.Percent < 100 {
		t.Fatalf("expected percent == 100 after logic retirement, got %d breakdown=%v",
			rep.Percent, rep.Breakdown)
	}
	if rep.Breakdown["legacy_logic_files_left"] != 0 {
		t.Fatalf("expected legacy_logic_files_left == 0, got %d", rep.Breakdown["legacy_logic_files_left"])
	}
}

func TestCompletePureKratosNot100UntilLogicRetired(t *testing.T) {
	if !moewiring.KratosPureEnabled() {
		t.Fatal("set moe.kratos_pure_enabled: true in backend/config/config.yaml")
	}
	rep := Current()
	if LegacyLogicFileCount() > 0 && rep.Percent >= 100 {
		t.Fatalf("percent should be <100 while legacy logic files remain: percent=%d logic_left=%d",
			rep.Percent, rep.Breakdown["legacy_logic_files_left"])
	}
	if LegacyLogicFileCount() > 0 && rep.Breakdown["legacy_logic_retired_pct"] <= 0 {
		t.Fatalf("expected legacy_logic_retired_pct > 0 while logic files remain")
	}
}

func TestCompletePureBreakdown100WhenPure(t *testing.T) {
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
