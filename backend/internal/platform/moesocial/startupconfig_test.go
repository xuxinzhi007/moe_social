package moesocial

import (
	"os"
	"path/filepath"
	"testing"
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

func TestResolveStartupPathsDefault(t *testing.T) {
	p := ResolveStartupPaths("", "")
	if p.Unified != defaultUnifiedConfig {
		t.Fatalf("unified=%q", p.Unified)
	}
	if p.APIFragment != defaultAPIFragment {
		t.Fatalf("api fragment=%q", p.APIFragment)
	}
}

func TestNormalizeOptions(t *testing.T) {
	o := Options{UnifiedConfigFile: "config/config.yaml"}
	o.NormalizeOptions()
	if o.APIConfigFile == "" {
		t.Fatalf("api=%q", o.APIConfigFile)
	}
}

func TestHTTPPortFromUnified(t *testing.T) {
	if p := httpPortFromUnified("config/config.yaml"); p != 8888 {
		t.Fatalf("http port want 8888, got %d", p)
	}
}
