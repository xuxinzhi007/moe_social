package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"

	"backend/pkg/conf"

	"gopkg.in/yaml.v3"
)

// flattenYAML 把 YAML 展开成「点路径 → 标量字符串」，便于逐键比对两份文件。
func flattenYAML(t *testing.T, path string) map[string]string {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("读 %s 失败: %v", path, err)
	}
	var root any
	if err := yaml.Unmarshal(raw, &root); err != nil {
		t.Fatalf("解析 %s 失败: %v", path, err)
	}
	out := map[string]string{}
	var walk func(prefix string, v any)
	walk = func(prefix string, v any) {
		switch val := v.(type) {
		case map[string]any:
			keys := make([]string, 0, len(val))
			for k := range val {
				keys = append(keys, k)
			}
			sort.Strings(keys)
			for _, k := range keys {
				key := k
				if prefix != "" {
					key = prefix + "." + k
				}
				walk(key, val[k])
			}
		case []any:
			for i, item := range val {
				walk(fmt.Sprintf("%s[%d]", prefix, i), item)
			}
		default:
			out[prefix] = fmt.Sprintf("%v", val)
		}
	}
	walk("", root)
	return out
}

func countCommentLines(t *testing.T, path string) (comments, lines int) {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("读 %s 失败: %v", path, err)
	}
	for _, line := range strings.Split(string(raw), "\n") {
		lines++
		if strings.HasPrefix(strings.TrimSpace(line), "#") {
			comments++
		}
	}
	return comments, lines
}

// TestPatchYAMLFilePreservesComments 固化「写回不得销毁注释与排版」这条不变量。
//
// 判别力：把 patchYAMLFile 换回 viper.Set + WriteConfig 就会失败 —— 实测旧实现对真实的
// backend/config/config.yaml 造成 10073→4416 字节、265→154 行、**79 行注释→0 行注释**，
// 并把 memory.search 的 3 个 float 静默降级成 int。管理台点一次「保存」就会不可逆抹掉
// 一个被 git 跟踪文件的全部注释。
//
// 第三条断言（除 5 个目标键外逐键全等）是闭合点：它保证定点写没有顺手改动任何别的东西。
func TestPatchYAMLFilePreservesComments(t *testing.T) {
	real := filepath.Join("..", "config", "config.yaml")
	if _, err := os.Stat(real); err != nil {
		t.Skipf("未找到 %s，跳过真实配置写回测试", real)
	}
	work := filepath.Join(t.TempDir(), "config.yaml")
	raw, err := os.ReadFile(real)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(work, raw, 0o644); err != nil {
		t.Fatal(err)
	}

	beforeComments, beforeLines := countCommentLines(t, work)
	if beforeComments == 0 {
		t.Fatalf("前置条件不成立：真实 config.yaml 应含注释，实测 0 行")
	}
	before := flattenYAML(t, work)

	patched := []string{
		"app_client.public_api_base_url",
		"api.public_base_url",
		"image.public_base_url",
		"image.local_dir",
		"image.max_bytes",
	}
	edits := []yamlEdit{
		{"app_client.public_api_base_url", "http://patched-app:8888"},
		{"api.public_base_url", "http://patched-api:8888"},
		{"image.public_base_url", "http://patched-image:8888"},
		{"image.local_dir", "/patched/images"},
		{"image.max_bytes", int64(1073741825)},
	}
	if err := patchYAMLFile(work, edits); err != nil {
		t.Fatalf("patchYAMLFile 失败: %v", err)
	}

	afterComments, afterLines := countCommentLines(t, work)
	if afterComments != beforeComments {
		t.Errorf("注释行数 %d → %d，写回销毁了注释", beforeComments, afterComments)
	}
	if afterLines != beforeLines {
		t.Errorf("总行数 %d → %d，写回改变了排版", beforeLines, afterLines)
	}

	after := flattenYAML(t, work)
	if len(after) != len(before) {
		t.Errorf("叶子键数 %d → %d", len(before), len(after))
	}
	patchSet := map[string]bool{}
	for _, k := range patched {
		patchSet[k] = true
	}
	for k, want := range before {
		if patchSet[k] {
			continue
		}
		if got := after[k]; got != want {
			t.Errorf("非目标键被改动 %s: %q → %q", k, want, got)
		}
	}
	wantVals := map[string]string{
		"app_client.public_api_base_url": "http://patched-app:8888",
		"api.public_base_url":            "http://patched-api:8888",
		"image.public_base_url":          "http://patched-image:8888",
		"image.local_dir":                "/patched/images",
		"image.max_bytes":                "1073741825",
	}
	for k, want := range wantVals {
		if got := after[k]; got != want {
			t.Errorf("目标键未生效 %s: got %q, want %q", k, got, want)
		}
	}

	// 文件权限不得被放宽：config.yaml 含数据库口令与第三方密钥。
	if fi, err := os.Stat(work); err != nil {
		t.Fatal(err)
	} else if fi.Mode().Perm() != 0o644 {
		t.Errorf("权限 %v, want 沿用原文件的 0644", fi.Mode().Perm())
	}

	// 改完必须能被 pkg/conf 正常读到，否则写回只是把文件改花而已。
	conf.ResetForTest()
	t.Cleanup(conf.ResetForTest)
	c, err := conf.LoadFile(work)
	if err != nil {
		t.Fatalf("写回后 conf.LoadFile 失败: %v", err)
	}
	if c.Image.MaxBytes != 1073741825 {
		t.Errorf("conf 读到 image.max_bytes = %d, want 1073741825", c.Image.MaxBytes)
	}
	if c.API.PublicBaseURL != "http://patched-api:8888" {
		t.Errorf("conf 读到 api.public_base_url = %q", c.API.PublicBaseURL)
	}
}

// TestResolveUnifiedConfigPathHonorsDashF 固化「写回路径以 -f 为权威」。
//
// 判别力：去掉 resolveUnifiedConfigPath 开头的 conf.Path() 分支就会失败 —— 旧实现只按 cwd
// 猜 ./config/config.yaml，于是读路径（conf.Reload → current.path）尊重 -f、写路径不尊重，
// 管理台一次保存会写到另一个文件，随后的 conf.LoadFile 还会把整个进程的配置源劫持过去。
func TestResolveUnifiedConfigPathHonorsDashF(t *testing.T) {
	// cwd 下放一个 searchDirs 能命中的哨兵文件（A），-f 指向另一个文件（B）。
	cwd := t.TempDir()
	if err := os.MkdirAll(filepath.Join(cwd, "config"), 0o755); err != nil {
		t.Fatal(err)
	}
	sentinelA := filepath.Join(cwd, "config", "config.yaml")
	if err := os.WriteFile(sentinelA, []byte("runtime:\n  http_port: 1111\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	sentinelB := filepath.Join(t.TempDir(), "custom.yaml")
	if err := os.WriteFile(sentinelB, []byte("runtime:\n  http_port: 2222\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Chdir(cwd)

	conf.ResetForTest()
	t.Cleanup(conf.ResetForTest)
	if _, err := conf.LoadFile(sentinelB); err != nil {
		t.Fatal(err)
	}
	if got := conf.Get().Runtime.HTTPPort; got != 2222 {
		t.Fatalf("前置条件不成立：conf 应已指向 B，实测 http_port = %d", got)
	}

	got, err := resolveUnifiedConfigPath()
	if err != nil {
		t.Fatalf("resolveUnifiedConfigPath 失败: %v", err)
	}
	wantB, err := filepath.Abs(sentinelB)
	if err != nil {
		t.Fatal(err)
	}
	if got != wantB && got != sentinelB {
		wantA, _ := filepath.Abs(sentinelA)
		t.Errorf("写回目标 = %s\n  want -f 指定的 %s\n  （若等于 %s 说明退回了 searchDirs，-f 权威被破坏）", got, wantB, wantA)
	}

	// 写回落到 B 之后，进程内缓存也必须跟着指向 B。
	if err := patchYAMLFile(got, []yamlEdit{{"runtime.http_port", int64(3333)}}); err != nil {
		t.Fatalf("patchYAMLFile 失败: %v", err)
	}
	if _, err := conf.LoadFile(got); err != nil {
		t.Fatalf("LoadFile 失败: %v", err)
	}
	if p := conf.Get().Runtime.HTTPPort; p != 3333 {
		t.Errorf("写回后 conf 读到 http_port = %d, want 3333", p)
	}
	if _, err := os.Stat(sentinelA); err != nil {
		t.Fatal(err)
	}
	if a := flattenYAML(t, sentinelA)["runtime.http_port"]; a != "1111" {
		t.Errorf("哨兵 A 被误写：runtime.http_port = %s, want 1111", a)
	}
}

// TestPatchYAMLFileMissingKey 固化新引入的边界行为：键不存在即报错且不落盘。
// 按行追加需要猜父块的缩进与结束位置，风险高于「让运维手工加一行」，所以宁可失败。
func TestPatchYAMLFileMissingKey(t *testing.T) {
	dir := t.TempDir()

	t.Run("行内注释与间距被保全", func(t *testing.T) {
		p := filepath.Join(dir, "comment.yaml")
		// 形状照抄真实 config.yaml 的 auth.access_expire_seconds：值 + 两个空格 + # 注释
		body := "# 顶部注释\nauth:\n  access_expire_seconds: 432000  # 5 天\n  access_secret: \"old\" # 紧贴一个空格\n"
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := patchYAMLFile(p, []yamlEdit{{"auth.access_expire_seconds", int64(86400)}}); err != nil {
			t.Fatalf("patchYAMLFile 失败: %v", err)
		}
		out, err := os.ReadFile(p)
		if err != nil {
			t.Fatal(err)
		}
		want := "# 顶部注释\nauth:\n  access_expire_seconds: 86400  # 5 天\n  access_secret: \"old\" # 紧贴一个空格\n"
		if string(out) != want {
			t.Errorf("写回结果不是逐字节预期：\n got %q\nwant %q", out, want)
		}
	})

	t.Run("叶子键缺失则报错且不落盘", func(t *testing.T) {
		p := filepath.Join(dir, "append.yaml")
		body := "# 顶部注释\nimage:\n  local_dir: \"/old\" # 行内注释\n"
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		err := patchYAMLFile(p, []yamlEdit{{"image.max_bytes", int64(42)}})
		if err == nil {
			t.Fatal("叶子键缺失时应返错，实际返回 nil")
		}
		if !strings.Contains(err.Error(), "image.max_bytes") {
			t.Errorf("错误信息未指出缺失的键: %v", err)
		}
		after, rerr := os.ReadFile(p)
		if rerr != nil {
			t.Fatal(rerr)
		}
		if string(after) != body {
			t.Errorf("失败时文件被改动了:\n%s", after)
		}
	})

	t.Run("中间层缺失则报错且不落盘", func(t *testing.T) {
		p := filepath.Join(dir, "reject.yaml")
		body := "# 注释\nruntime:\n  http_port: 8888\n"
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		err := patchYAMLFile(p, []yamlEdit{{"nonexistent.deep.key", "x"}})
		if err == nil {
			t.Fatal("中间层缺失时应返错，实际返回 nil")
		}
		if !strings.Contains(err.Error(), "nonexistent.deep.key") {
			t.Errorf("错误信息未指出缺失的键: %v", err)
		}
		after, rerr := os.ReadFile(p)
		if rerr != nil {
			t.Fatal(rerr)
		}
		if string(after) != body {
			t.Errorf("失败时文件被改动了:\n%s", after)
		}
	})

	t.Run("不支持的类型报错", func(t *testing.T) {
		p := filepath.Join(dir, "type.yaml")
		if err := os.WriteFile(p, []byte("runtime:\n  http_port: 8888\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := patchYAMLFile(p, []yamlEdit{{"runtime.http_port", 3.14}}); err == nil {
			t.Error("float64 不在支持类型内，应返错")
		}
	})

	t.Run("空 edits 不落盘", func(t *testing.T) {
		p := filepath.Join(dir, "noop.yaml")
		body := "# 注释\nruntime:\n  http_port: 8888\n"
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := patchYAMLFile(p, nil); err != nil {
			t.Fatalf("空 edits 应直接返回 nil，got %v", err)
		}
		after, err := os.ReadFile(p)
		if err != nil {
			t.Fatal(err)
		}
		if string(after) != body {
			t.Errorf("空 edits 却改动了文件:\n%s", after)
		}
	})
}
