package mediabiz

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// setupTestDir 创建 t.TempDir() 下的用户目录并写入指定文件，返回可用配置。
func setupTestDir(t *testing.T, userFolder string, filenames ...string) ImageConfig {
	t.Helper()
	dir := t.TempDir()
	userDir := filepath.Join(dir, userFolder)
	if err := os.MkdirAll(userDir, 0o755); err != nil {
		t.Fatalf("mkdir user dir: %v", err)
	}
	for _, name := range filenames {
		if err := os.WriteFile(filepath.Join(userDir, name), []byte("data-"+name), 0o644); err != nil {
			t.Fatalf("write file %s: %v", name, err)
		}
	}
	return ImageConfig{LocalDir: dir, PublicBaseURL: "http://test.local"}
}

func TestOpenImageContentType(t *testing.T) {
	cfg := setupTestDir(t, "u1", "a.m4a", "b.xyz", "c.png")

	cases := []struct {
		key  string
		want string
	}{
		{"u1__a.m4a", "audio/mp4"},
		{"u1__b.xyz", "image/jpeg"}, // 未知扩展锁死兼容行为：落回 image/jpeg
		{"u1__c.png", "image/png"},
	}
	for _, tc := range cases {
		f, err := OpenImage(context.Background(), cfg, tc.key)
		if err != nil {
			t.Fatalf("OpenImage(%s): %v", tc.key, err)
		}
		if f.Body != nil {
			_ = f.Body.Close()
		}
		if f.ContentType != tc.want {
			t.Errorf("OpenImage(%s) ContentType = %q, want %q", tc.key, f.ContentType, tc.want)
		}
	}
}

func TestListImagesFiltersNonImages(t *testing.T) {
	cfg := setupTestDir(t, "u1", "a.png", "b.jpg", "voice.m4a", "note.txt")

	res, err := ListImages(context.Background(), cfg, ListImagesInput{UserFolder: "u1", Page: 1, PageSize: 10})
	if err != nil {
		t.Fatalf("ListImages: %v", err)
	}
	if res.Total != 2 {
		t.Fatalf("Total = %d, want 2 (仅统计图片)", res.Total)
	}
	if len(res.Items) != 2 {
		t.Fatalf("len(Items) = %d, want 2", len(res.Items))
	}
	for _, item := range res.Items {
		if strings.Contains(item.Filename, "voice.m4a") || strings.Contains(item.Filename, "note.txt") {
			t.Errorf("非图片文件混入列表: %s", item.Filename)
		}
	}
}

func TestUploadImageExtensionWhitelist(t *testing.T) {
	cfg := setupTestDir(t, "u1")

	// 合法扩展名（图片与音频）应成功。
	for _, name := range []string{"pic.png", "voice.m4a"} {
		info, err := UploadImage(context.Background(), cfg, UploadInput{
			UserFolder: "u1",
			OrigName:   name,
			Reader:     strings.NewReader("content"),
		})
		if err != nil {
			t.Errorf("UploadImage(%s) 返回错误: %v", name, err)
			continue
		}
		if info.ID == "" {
			t.Errorf("UploadImage(%s) 返回空 ID", name)
		}
	}

	// 非法扩展名应被拒绝。
	if _, err := UploadImage(context.Background(), cfg, UploadInput{
		UserFolder: "u1",
		OrigName:   "malware.exe",
		Reader:     strings.NewReader("content"),
	}); err == nil {
		t.Error("UploadImage(malware.exe) 应返回错误，实际成功")
	}
}

func TestUploadImageWindowsOrigName(t *testing.T) {
	cfg := setupTestDir(t, "u1")
	const winPath = `C:\Users\foo\AppData\Local\Temp\voice_123.m4a`

	info, err := UploadImage(context.Background(), cfg, UploadInput{
		UserFolder: "u1",
		OrigName:   winPath,
		Reader:     strings.NewReader("aac-bytes"),
	})
	if err != nil {
		t.Fatalf("UploadImage(windows OrigName): %v", err)
	}
	if !strings.HasSuffix(info.Filename, "voice_123.m4a") {
		t.Fatalf("Filename = %q, want suffix voice_123.m4a", info.Filename)
	}
	if strings.Contains(info.Filename, `\`) || strings.Contains(info.Filename, "Users") {
		t.Fatalf("Filename 仍含 Windows 路径片段: %q", info.Filename)
	}

	opened, err := OpenImage(context.Background(), cfg, info.Filename)
	if err != nil {
		t.Fatalf("OpenImage after windows OrigName: %v", err)
	}
	if opened.Body != nil {
		_ = opened.Body.Close()
	}
	if opened.ContentType != "audio/mp4" {
		t.Fatalf("ContentType = %q, want audio/mp4", opened.ContentType)
	}
}

func TestSafeOrigBaseName(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{`C:\Temp\voice.m4a`, "voice.m4a"},
		{`C:/Temp/voice.m4a`, "voice.m4a"},
		{"/tmp/voice.m4a", "voice.m4a"},
		{"voice.m4a", "voice.m4a"},
		{"", ""},
		{`\`, ""},
	}
	for _, tc := range cases {
		if got := safeOrigBaseName(tc.in); got != tc.want {
			t.Errorf("safeOrigBaseName(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}
