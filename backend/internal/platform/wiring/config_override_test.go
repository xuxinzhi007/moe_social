package runserver

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	mediav1 "backend/api/media/v1"
	platformv1 "backend/api/platform/v1"
	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/apiconfig"
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
	"backend/internal/server"
	mediahttp "backend/internal/server/protohttp/media"
	platformhttp "backend/internal/server/protohttp/platform"
	"backend/pkg/conf"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/protobuf/encoding/protojson"
)

// 本包的 cwd 下 ./config、../config、../../config 三个 searchDirs 都不存在，
// 所以 readInferenceFragment() 必定返回 nil —— 这正好复现了「viper 找不到文件」的分支。
// 改动前该分支是整个 ApplyUnifiedConfigOverrides 提前 return，下面这些断言全部为真才说明
// pkg/conf 的覆盖已经不再被 viper 的失败牵连。

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

// config.yaml 没写这些段时，片段 api/etc/moe.yaml 里的值必须存活。
//
// 断言的是「仅当值非空/为正才覆盖」这条语义 —— 它存在的唯一理由就是 c 来自
// api/etc/moe.yaml 片段。谁把某个 if 拆掉改成无条件赋值，片段值就会被零值冲掉，
// 这里立刻红。曾经用 local_models 段当载体，那段连同离线模型链路在 #42 整条删除，
// 于是换成今天仍然活着的 image / auth 两段。
func TestOverridesLeaveFragmentValuesWhenConfSilent(t *testing.T) {
	writeConf(t, "runtime:\n  http_port: 8888\n")

	c := apiconfig.Config{}
	c.Image.MaxBytes = 1073741824
	c.Image.LocalDir = "/app/data/images"
	c.Auth.AccessExpire = 432000
	ApplyUnifiedConfigOverrides(&c)

	if c.Image.MaxBytes != 1073741824 {
		t.Errorf("Image.MaxBytes = %d, want 保留片段的 1073741824", c.Image.MaxBytes)
	}
	if c.Image.LocalDir != "/app/data/images" {
		t.Errorf("Image.LocalDir = %q, want 保留片段的 /app/data/images", c.Image.LocalDir)
	}
	if c.Auth.AccessExpire != 432000 {
		t.Errorf("Auth.AccessExpire = %d, want 保留片段的 432000", c.Auth.AccessExpire)
	}
}

// 反向钉子：config.yaml 里确实写了值时，必须盖掉片段值。
// 只有上面那条「保留」断言的话，把 ApplyUnifiedConfigOverrides 整个函数体删空
// 也能全绿 —— 这条保证覆盖逻辑本身还在工作。
func TestOverridesApplyConfValuesOverFragment(t *testing.T) {
	writeConf(t, "image:\n  local_dir: \"/from/conf\"\n  max_bytes: 42\n")

	c := apiconfig.Config{}
	c.Image.MaxBytes = 1073741824
	c.Image.LocalDir = "/app/data/images"
	ApplyUnifiedConfigOverrides(&c)

	if c.Image.LocalDir != "/from/conf" {
		t.Errorf("Image.LocalDir = %q, want /from/conf", c.Image.LocalDir)
	}
	if c.Image.MaxBytes != 42 {
		t.Errorf("Image.MaxBytes = %d, want 42", c.Image.MaxBytes)
	}
}

func TestPublicAndMediaConfigHTTP(t *testing.T) {
	if err := utils.ConfigureJWT("fixture-jwt-signing-key", 3600); err != nil {
		t.Fatal(err)
	}
	token, err := utils.GenerateToken(7, "fixture")
	if err != nil {
		t.Fatal(err)
	}
	for _, tt := range []struct {
		name, body, client, image string
	}{
		{"canonical", "api: {public_base_url: 'https://api.example.test/'}", "https://api.example.test", "https://api.example.test"},
		{"empty overrides", "api: {public_base_url: 'https://api.example.test'}\napp_client: {public_api_base_url: ''}\nimage: {public_base_url: ''}", "https://api.example.test", "https://api.example.test"},
		{"explicit overrides", "api: {public_base_url: 'https://api.example.test'}\napp_client: {public_api_base_url: 'https://client.example.test/'}\nimage: {public_base_url: 'https://images.example.test/'}", "https://client.example.test", "https://images.example.test"},
		{"historical client", "app_client: {public_api_base_url: 'https://client.example.test/'}", "https://client.example.test", "https://client.example.test"},
		{"missing preserves fragment", "{}", "", "https://fragment.example.test"},
		{"empty preserves fragment", "api: {public_base_url: ''}\nimage: {public_base_url: ''}", "", "https://fragment.example.test"},
		{"slash cannot become valid base", "api: {public_base_url: '///'}\napp_client: {public_api_base_url: '/'}\nimage: {public_base_url: '///'}", "", "https://fragment.example.test"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			writeConf(t, tt.body)
			c := apiconfig.Config{Image: apiconfig.ImageConf{
				Driver: mediabiz.DriverLocal, LocalDir: t.TempDir(), PublicBaseUrl: "https://fragment.example.test/",
				OSS: apiconfig.ImageOSS{Endpoint: "oss.example.test", Bucket: "fixture-bucket", PublicBaseUrl: "https://cdn.example.test/assets", ProxyViaAPI: true},
			}}
			ApplyUnifiedConfigOverrides(&c)
			ctx := &svc.ServiceContext{Config: c}
			wirePlatformServices(ctx, c.Image)
			if ctx.MediaApp == nil {
				t.Fatal("media service not wired")
			}
			postCfg := moewiring.ImageConfigFromAPI(c.Image)
			if got := ctx.MediaApp.Config(); got != postCfg || got.PublicBaseURL != tt.image {
				t.Fatal("post and media must share effective configuration including fragment fallback")
			}
			if postCfg.OSS.PublicBaseURL != "https://cdn.example.test/assets" || postCfg.OSS.Endpoint != "oss.example.test" || !postCfg.OSS.ProxyViaAPI {
				t.Fatal("OSS/CDN configuration must remain independent of API public base")
			}
			folder := mediabiz.FolderNameForUser(7, "fixture")
			if err := ctx.MediaApp.Store().Put(context.Background(), folder, "fixture.png", strings.NewReader("fixture"), "image/png"); err != nil {
				t.Fatal(err)
			}
			h := khttp.NewServer(khttp.ResponseEncoder(server.EnvelopeResponseEncoder), khttp.ErrorEncoder(server.EnvelopeErrorEncoder))
			platformv1.RegisterPlatformHTTPServer(h, platformhttp.New(platformhttp.DepsFromServiceContext(ctx)))
			mediav1.RegisterMediaHTTPServer(h, mediahttp.New(ctx.MediaApp))
			httpServer := httptest.NewServer(h)
			defer httpServer.Close()
			get := func(path string, wantStatus int) json.RawMessage {
				t.Helper()
				req, err := http.NewRequest(http.MethodGet, httpServer.URL+path, nil)
				if err != nil {
					t.Fatal(err)
				}
				req.Header.Set("Authorization", "Bearer "+token)
				resp, err := httpServer.Client().Do(req)
				if err != nil {
					t.Fatal(err)
				}
				defer resp.Body.Close()
				if resp.StatusCode != wantStatus {
					t.Fatalf("%s status = %d, want %d", path, resp.StatusCode, wantStatus)
				}
				var envelope struct {
					Success bool            `json:"success"`
					Data    json.RawMessage `json:"data"`
				}
				if err := json.NewDecoder(resp.Body).Decode(&envelope); err != nil {
					t.Fatal(err)
				}
				if envelope.Success != (wantStatus == http.StatusOK) {
					t.Fatal("HTTP status and envelope success disagree")
				}
				return envelope.Data
			}
			checkResponses := func() {
				t.Helper()
				if tt.client == "" {
					get("/api/public/client-config", http.StatusNotFound)
				} else {
					var out platformv1.GetPublicClientConfigResp
					if err := protojson.Unmarshal(get("/api/public/client-config", http.StatusOK), &out); err != nil {
						t.Fatal(err)
					}
					if out.ApiBaseUrl != tt.client {
						t.Fatalf("client URL = %q, want %q", out.ApiBaseUrl, tt.client)
					}
				}
				var out mediav1.ListImagesReply
				if err := protojson.Unmarshal(get("/api/images", http.StatusOK), &out); err != nil {
					t.Fatal(err)
				}
				want := tt.image + "/api/images/" + folder + "__fixture.png"
				if len(out.Images) != 1 || out.Images[0].Url != want {
					t.Fatalf("media URL must use effective base %q", want)
				}
			}
			checkResponses()
			// 文件缓存刷新不会重建已注入服务；管理台必须要求重启。
			writeConf(t, "api: {public_base_url: 'https://after-restart.example.test'}")
			checkResponses()
		})
	}
}
