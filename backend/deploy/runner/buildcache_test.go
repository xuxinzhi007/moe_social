package runner

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestApplyDeployBuildCache(t *testing.T) {
	dir := t.TempDir()
	env := ApplyDeployBuildCache([]string{"PATH=/bin"}, dir)
	m := envSliceToMap(env)
	goCache, tmp := DeployCachePaths(dir)
	if m["GOCACHE"] != goCache {
		t.Fatalf("GOCACHE=%q want %q", m["GOCACHE"], goCache)
	}
	if m["TMPDIR"] != tmp {
		t.Fatalf("TMPDIR=%q want %q", m["TMPDIR"], tmp)
	}
}

func TestCleanBuildCache(t *testing.T) {
	root := t.TempDir()
	goCache, tmp := DeployCachePaths(root)
	_ = os.MkdirAll(goCache, 0o755)
	_ = os.MkdirAll(tmp, 0o755)
	_ = os.WriteFile(filepath.Join(tmp, "x"), []byte("hello"), 0o644)

	backend := t.TempDir()
	bin := filepath.Join(backend, "api", "moe-social-api")
	_ = os.MkdirAll(filepath.Dir(bin), 0o755)
	_ = os.WriteFile(bin, []byte("bin"), 0o644)

	freed, err := CleanBuildCache(root, backend, true)
	if err != nil {
		t.Fatal(err)
	}
	if freed < 5 {
		t.Fatalf("freed=%d", freed)
	}
	if _, err := os.Stat(bin); !os.IsNotExist(err) {
		t.Fatal("binary should be removed")
	}
}

func TestBuildProcessEnvUsesDeployCache(t *testing.T) {
	root := t.TempDir()
	SetDeployBuildCacheRoot(root)
	t.Cleanup(func() { SetDeployBuildCacheRoot("") })

	env := BuildProcessEnv("")
	m := envSliceToMap(env)
	if !strings.HasPrefix(m["GOCACHE"], root) {
		t.Fatalf("GOCACHE=%q", m["GOCACHE"])
	}
}
