package runserver

import (
	"os"
	"path/filepath"
	"testing"

	"backend/internal/platform/apiconfig"
	"backend/pkg/conf"
)

// 本包的 cwd 下 ./config、../config、../../config 三个 searchDirs 都不存在，
// 所以 readInferenceFragment() 必定返回 nil —— 这正好复现了「viper 找不到文件」的分支。
// 改动前该分支是整个 ApplyUnifiedConfigOverrides 提前 return，下面这些断言全部为真才说明
// pkg/conf 的覆盖已经不再被 viper 的失败牵连。

const localModelsYAML = `local_models:
  storage_dir: "data/gguf"
  catalog:
    - id: probe-model
      name: "探针模型"
      filename: probe.gguf
      size_bytes: 64
      sha256: "ABC123"
      description: "探针"
      parameters_b: 0.5
      recommended: true
`

func writeConf(t *testing.T, body string) string {
	t.Helper()
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, "probe.yaml")
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(conf.ResetForTest)
	if _, err := conf.LoadFile(path); err != nil {
		t.Fatalf("conf.LoadFile: %v", err)
	}
	return path
}

// apiconfig.LocalModelCatalogEntry 只有 json/yaml tag，用 v.UnmarshalKey 解码时
// mapstructure 按字段名匹配，size_bytes / parameters_b 因下划线对不上而静默丢值。
// 值必须是合成的非零值，否则「丢成 0」和「本来就是 0」分不出来。
func TestOverridesKeepUnderscoreCatalogFields(t *testing.T) {
	writeConf(t, localModelsYAML)

	var c apiconfig.Config
	ApplyUnifiedConfigOverrides(&c)

	if c.LocalModels.StorageDir != "data/gguf" {
		t.Fatalf("StorageDir = %q, want data/gguf", c.LocalModels.StorageDir)
	}
	if len(c.LocalModels.Catalog) != 1 {
		t.Fatalf("Catalog 长度 = %d, want 1", len(c.LocalModels.Catalog))
	}
	e := c.LocalModels.Catalog[0]
	if e.ParametersB != 0.5 {
		t.Errorf("ParametersB = %v, want 0.5", e.ParametersB)
	}
	if e.SizeBytes != 64 {
		t.Errorf("SizeBytes = %d, want 64", e.SizeBytes)
	}
	if e.Id != "probe-model" || e.Filename != "probe.gguf" {
		t.Errorf("Id/Filename = %q/%q", e.Id, e.Filename)
	}
	if e.Sha256 != "ABC123" || !e.Recommended {
		t.Errorf("Sha256/Recommended = %q/%v", e.Sha256, e.Recommended)
	}
}

// config.yaml 没写 local_models 时，片段 api/etc/moe.yaml 里的值必须存活。
func TestOverridesLeaveFragmentValuesWhenConfSilent(t *testing.T) {
	writeConf(t, "runtime:\n  http_port: 8888\n")

	c := apiconfig.Config{}
	c.LocalModels.StorageDir = "fragment-dir"
	c.LocalModels.Catalog = []apiconfig.LocalModelCatalogEntry{{Id: "fragment-model"}}
	ApplyUnifiedConfigOverrides(&c)

	if c.LocalModels.StorageDir != "fragment-dir" {
		t.Errorf("StorageDir = %q, want fragment-dir", c.LocalModels.StorageDir)
	}
	if len(c.LocalModels.Catalog) != 1 || c.LocalModels.Catalog[0].Id != "fragment-model" {
		t.Errorf("Catalog = %+v, want 保留 fragment-model", c.LocalModels.Catalog)
	}
}
