package moesocial

import (
	"os"
	"path/filepath"
	"testing"

	"backend/pkg/conf"
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

// -f 必须让整个进程的 pkg/conf 缓存指向该文件。此前 -f 只影响端口与片段路径，
// DSN、JWT 密钥等其余读者仍走 searchDirs —— 同一次启动读两个不同的文件。
func TestUnifiedFlagIsAuthoritativeForAllReaders(t *testing.T) {
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	alt := filepath.Join(dir, "alt.yaml")
	if err := os.WriteFile(alt, []byte("runtime:\n  http_port: 9955\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(conf.ResetForTest)

	if p := httpPortFromUnified(alt); p != 9955 {
		t.Fatalf("http port want 9955, got %d", p)
	}
	if got := conf.Path(); got != alt {
		t.Fatalf("conf.Path want %q, got %q", alt, got)
	}
	if got := conf.Get().Runtime.HTTPPort; got != 9955 {
		t.Fatalf("conf.Get want 9955, got %d", got)
	}
}
