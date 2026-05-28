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
	if rep.RolloutPercent >= 100 && rep.Percent >= rep.RolloutPercent {
		t.Fatalf("complete pure (%d) should be below transport rollout (%d) until native handlers/grpc",
			rep.Percent, rep.RolloutPercent)
	}
}

func TestCompletePureKratosAtLeast50(t *testing.T) {
	rep := Current()
	if rep.Percent < 50 {
		t.Fatalf("expected complete pure kratos percent >= 50, got %d breakdown=%v",
			rep.Percent, rep.Breakdown)
	}
	if rep.PPercent != rep.Percent {
		t.Fatalf("p_percent should match percent, got %d vs %d", rep.PPercent, rep.Percent)
	}
}

func TestCompletePureKratosAtLeast90(t *testing.T) {
	rep := Current()
	if rep.Percent < 90 {
		t.Fatalf("expected complete pure kratos percent >= 90, got %d breakdown=%v",
			rep.Percent, rep.Breakdown)
	}
	if rep.Breakdown["http_bridge_handler_pct"] > 5 {
		t.Fatalf("expected bridge routes only swagger, bridge_pct=%d",
			rep.Breakdown["http_bridge_handler_pct"])
	}
}

func TestCompletePureBreakdownKeys(t *testing.T) {
	rep := Current()
	for _, k := range []string{
		"http_native_handler_pct",
		"http_bridge_handler_pct",
		"grpc_transport_kratos_pct",
		"complete_pure_kratos_pct",
	} {
		if _, ok := rep.Breakdown[k]; !ok {
			t.Fatalf("missing breakdown key %q", k)
		}
	}
	if rep.Breakdown["grpc_transport_kratos_pct"] != 0 {
		t.Fatal("Super still on zrpc: grpc_transport_kratos_pct should be 0")
	}
}
