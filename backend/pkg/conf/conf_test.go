package conf

import (
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// fixture 覆盖迁移前 20 处读取点会碰到的全部形状：驼峰键（database.parseTime）、
// 字符串端口（moe.production.external_http_port）、历史扁平键（wechat.mobile_app_id）、
// 以及「显式 false」与「未设置」两种开关。
//
// 「列表套结构体」这一形状已不再被覆盖：唯一载体 local_models.catalog 随离线 GGUF
// 链路在 #42 整条删除，pkg/conf 现在没有任何切片型配置键。将来新增列表型键时，
// 这里没有现成的钉子 —— 记得补一条 fixture 与断言。
const fixture = `
runtime:
  http_host: "0.0.0.0"
  http_port: 8888
  hand_draw_require_moderation: false
  api_config_fragment: api/etc/moe.yaml

auth:
  access_secret: "file-auth-secret"
  access_expire_seconds: 432000

admin:
  jwt_secret: "file-admin-secret"
  token_expire_hours: 168
  bootstrap:
    username: "admin"
    password: "admin123"

api:
  public_base_url: "http://api.example.com:8888/"

database:
  host: "127.0.0.1"
  port: 3306
  user: "root"
  password: "pw"
  dbname: "go_react_demo"
  charset: "utf8mb4"
  parseTime: true
  loc: "Local"

image:
  driver: local
  local_dir: "/app/data/images"
  public_base_url: "http://img.example.com:8888/"
  max_bytes: 1073741824
  oss:
    endpoint: "oss-cn-shenzhen.aliyuncs.com"
    bucket: "moe-social-media"
    access_key_id: "file-ak"
    access_key_secret: ""
    prefix: "media"
    public_base_url: ""
    region: "cn-shenzhen"
    proxy_via_api: false

app_client:
  public_api_base_url: "http://client.example.com:8888"

llm_inference:
  provider: ollama
  base_url: "http://192.168.124.77:11434"
  api_style: ollama
  timeout_seconds: 120
  memory_model: "qwen2.5:3b-instruct"
  chat_model: ""
  api_key: ""
  game_base_url: "http://127.0.0.1:6633"
  game_model: ""
  game_llm_mode: "narrator"
  context_tokens: 32768

temp_mail:
  enabled: true
  base_url: "https://api.mail.tm"
  fallback_domain: "web-library.net"
  timeout_seconds: 30

private_message:
  retention_days_default: 30
  retention_days_normal: 7
  retention_days_vip: 90
  body_max_runes: 8000
  image_paths_max: 9

feishu:
  enabled: true
  app_id: "cli_test"
  app_secret: "fs-secret"
  receive_id: "someone@example.com"
  receive_id_type: "email"
  redirect_uri: ""
  oauth_scope: "contact:user.email:readonly"

wechat:
  enabled: true
  redirect_uri: "http://api.example.com:8888/api/auth/wechat/callback"
  app:
    app_id: "wx-app-id"
    app_secret: "wx-app-secret"
  website:
    app_id: ""
    app_secret: ""
  mp:
    app_id: ""
    app_secret: ""
  mobile_app_id: "wx-legacy-mobile-id"
  web_app_id: "wx-legacy-web-id"

moe:
  bot_post_model: "qwen2"
  bot_scheduler_enabled: true
  bot_scheduler_tick_seconds: 60
  dream_scheduler_enabled: true
  dream_scheduler_tick_seconds: 300
  bot_smart_retry_minutes: 30
  bot_smart_min_interval_hours: 2
  api_in_process: true
  single_process: true
  life_engine_enabled: true
  user_api_in_process: true
  vip_api_in_process: false
  production:
    unified_entry: moe-social
    external_http_port: "9999"
`

func loadFixture(t *testing.T) *Config {
	t.Helper()
	path := filepath.Join(t.TempDir(), "config.yaml")
	if err := os.WriteFile(path, []byte(fixture), 0o600); err != nil {
		t.Fatalf("写 fixture 失败: %v", err)
	}
	ResetForTest()
	t.Cleanup(ResetForTest)
	cfg, err := LoadFile(path)
	if err != nil {
		t.Fatalf("LoadFile 失败: %v", err)
	}
	return cfg
}

// loadBody 载入自定义 YAML。fixture 把键写全了，表达不了「键完全不存在」这种形状，
// 而未设置与显式 false 的区分正是 inheritBool 一族的存在理由。
func loadBody(t *testing.T, body string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "config.yaml")
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatalf("写配置失败: %v", err)
	}
	ResetForTest()
	t.Cleanup(ResetForTest)
	if _, err := LoadFile(path); err != nil {
		t.Fatalf("LoadFile 失败: %v", err)
	}
}

// TestTypedMirror 断言类型化结构与 YAML 逐字段对应。
// 这里最容易出错的是 database.parseTime：viper 会把键小写成 parsetime，
// tag 写成 parse_time 就会静默拿到 false。
func TestTypedMirror(t *testing.T) {
	c := loadFixture(t)

	if c.Runtime.HTTPPort != 8888 {
		t.Errorf("Runtime.HTTPPort = %d, want 8888", c.Runtime.HTTPPort)
	}
	if c.Runtime.APIConfigFragment != "api/etc/moe.yaml" {
		t.Errorf("Runtime.APIConfigFragment = %q", c.Runtime.APIConfigFragment)
	}
	if c.Auth.AccessExpireSeconds != 432000 {
		t.Errorf("Auth.AccessExpireSeconds = %d", c.Auth.AccessExpireSeconds)
	}
	if c.Admin.Bootstrap.Username != "admin" || c.Admin.Bootstrap.Password != "admin123" {
		t.Errorf("Admin.Bootstrap = %+v", c.Admin.Bootstrap)
	}
	if !c.Database.ParseTime {
		t.Error("Database.ParseTime = false, want true（驼峰键 parseTime 未被识别）")
	}
	if c.Database.DBName != "go_react_demo" || c.Database.Port != 3306 {
		t.Errorf("Database = %+v", c.Database)
	}
	if c.Image.MaxBytes != 1073741824 || c.Image.OSS.Bucket != "moe-social-media" {
		t.Errorf("Image = %+v", c.Image)
	}
	if c.LLMInference.ContextTokens != 32768 || c.LLMInference.GameLLMMode != "narrator" {
		t.Errorf("LLMInference = %+v", c.LLMInference)
	}
	if c.PrivateMessage.BodyMaxRunes != 8000 || c.PrivateMessage.RetentionDaysVIP != 90 {
		t.Errorf("PrivateMessage = %+v", c.PrivateMessage)
	}
	if c.TempMail.FallbackDomain != "web-library.net" || c.TempMail.TimeoutSeconds != 30 {
		t.Errorf("TempMail = %+v", c.TempMail)
	}
	if c.Moe.Production.ExternalHTTPPort != "9999" {
		t.Errorf("Moe.Production.ExternalHTTPPort = %q", c.Moe.Production.ExternalHTTPPort)
	}
	if c.Feishu.ReceiveIDType != "email" || c.Feishu.AppID != "cli_test" {
		t.Errorf("Feishu = %+v", c.Feishu)
	}
}

// TestDSN 与 utils/db.go 的连接串格式逐字段对齐。
func TestDSN(t *testing.T) {
	loadFixture(t)
	want := "root:pw@tcp(127.0.0.1:3306)/go_react_demo?charset=utf8mb4&parseTime=true&loc=Local"
	if got := DSN(); got != want {
		t.Errorf("DSN()\n got = %s\nwant = %s", got, want)
	}
}

// TestHTTPPort 覆盖 moesocial.httpPortFromUnified 的两级回退：
// runtime.http_port 优先，缺失时才解析字符串型 moe.production.external_http_port。
func TestHTTPPort(t *testing.T) {
	loadFixture(t)
	if got := HTTPPort(); got != 8888 {
		t.Errorf("HTTPPort() = %d, want 8888（runtime 段优先于 production 段）", got)
	}

	ResetForTest()
	path := filepath.Join(t.TempDir(), "config.yaml")
	if err := os.WriteFile(path, []byte("moe:\n  production:\n    external_http_port: \"9999\"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadFile(path); err != nil {
		t.Fatal(err)
	}
	if got := HTTPPort(); got != 9999 {
		t.Errorf("无 runtime 段时 HTTPPort() = %d, want 9999", got)
	}
}

// TestPublicBaseURL 断言末尾斜杠被去掉，且 api.public_base_url 优先于 app_client。
func TestPublicBaseURL(t *testing.T) {
	loadFixture(t)
	if got := PublicBaseURL(); got != "http://api.example.com:8888" {
		t.Errorf("PublicBaseURL() = %q", got)
	}
	if got := ImagePublicBaseURL(); got != "http://img.example.com:8888" {
		t.Errorf("ImagePublicBaseURL() = %q", got)
	}
	// feishu.redirect_uri 留空时由 PublicBaseURL 拼回调
	if got := FeishuRedirectURI(); got != "http://api.example.com:8888/api/auth/feishu/callback" {
		t.Errorf("FeishuRedirectURI() = %q", got)
	}
	// wechat.redirect_uri 已显式配置，不应被覆盖
	if got := WechatRedirectURI(); got != "http://api.example.com:8888/api/auth/wechat/callback" {
		t.Errorf("WechatRedirectURI() = %q", got)
	}
}

func TestPublicURLDerivationMatrix(t *testing.T) {
	const public = "https://api.example.test"
	const client = "https://client.example.test"
	const image = "https://images.example.test"
	for _, tt := range []struct {
		name, body            string
		public, client, image string
		feishu, wechat        string
	}{
		{name: "missing", body: "{}"},
		{name: "empty", body: "api: {public_base_url: ''}\napp_client: {public_api_base_url: ''}\nimage: {public_base_url: ''}"},
		{name: "canonical only", body: "api: {public_base_url: ' https://api.example.test/// '}", public: public, client: public, image: public},
		{name: "empty overrides", body: "api: {public_base_url: 'https://api.example.test'}\napp_client: {public_api_base_url: ''}\nimage: {public_base_url: ''}\nfeishu: {redirect_uri: ''}\nwechat: {redirect_uri: ''}", public: public, client: public, image: public},
		{name: "historical client", body: "app_client: {public_api_base_url: 'https://client.example.test/'}", public: client, client: client, image: client},
		{name: "independent overrides", body: "api: {public_base_url: 'https://api.example.test'}\napp_client: {public_api_base_url: 'https://client.example.test/'}\nimage: {public_base_url: 'https://images.example.test/'}\nfeishu: {redirect_uri: 'https://oauth.example.test/feishu/'}\nwechat: {redirect_uri: 'https://oauth.example.test/wechat/'}", public: public, client: client, image: image, feishu: "https://oauth.example.test/feishu/", wechat: "https://oauth.example.test/wechat/"},
		{name: "slash canonical falls back", body: "api: {public_base_url: '///'}\napp_client: {public_api_base_url: 'https://client.example.test'}", public: client, client: client, image: client},
		{name: "slash overrides derive", body: "api: {public_base_url: 'https://api.example.test'}\napp_client: {public_api_base_url: '/'}\nimage: {public_base_url: '///'}\nfeishu: {redirect_uri: '/'}\nwechat: {redirect_uri: '///'}", public: public, client: public, image: public},
		{name: "only slashes", body: "api: {public_base_url: '/'}\napp_client: {public_api_base_url: '///'}\nimage: {public_base_url: '/'}\nfeishu: {redirect_uri: '///'}\nwechat: {redirect_uri: '/'}"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			loadBody(t, tt.body)
			if tt.public != "" {
				if tt.feishu == "" {
					tt.feishu = tt.public + "/api/auth/feishu/callback"
				}
				if tt.wechat == "" {
					tt.wechat = tt.public + "/api/auth/wechat/callback"
				}
			}
			got := []string{PublicBaseURL(), ClientPublicBaseURL(), ImagePublicBaseURL(), FeishuRedirectURI(), WechatRedirectURI()}
			want := []string{tt.public, tt.client, tt.image, tt.feishu, tt.wechat}
			for i := range want {
				if got[i] != want[i] {
					t.Errorf("derived URL %d = %q, want %q", i, got[i], want[i])
				}
			}
		})
	}
}

func TestAgoraTypedConfig(t *testing.T) {
	loadBody(t, "agora: {app_id: 'fake-id', app_certificate: 'fake-certificate'}")
	if Get().Agora.AppID != "fake-id" || Get().Agora.AppCertificate != "fake-certificate" {
		t.Fatal("typed Agora keys were not decoded")
	}
	loadBody(t, "agora: {app_id: ''}")
	if !IsSet("agora.app_id") || IsSet("agora.app_certificate") {
		t.Fatal("explicit empty and absent credentials must remain distinguishable")
	}
}

// TestInferenceResolution 复现 moeconfig.InferenceFromViper 的
// 环境变量 → llm_inference → ollama 三级链。
func TestInferenceResolution(t *testing.T) {
	loadFixture(t)

	cfg := Inference()
	if cfg.BaseURL != "http://192.168.124.77:11434" {
		t.Errorf("BaseURL = %q", cfg.BaseURL)
	}
	if cfg.DefaultModel != "qwen2.5:3b-instruct" {
		t.Errorf("DefaultModel = %q", cfg.DefaultModel)
	}
	if cfg.Timeout.Seconds() != 120 {
		t.Errorf("Timeout = %v", cfg.Timeout)
	}
	if string(cfg.APIStyle) != "ollama" {
		t.Errorf("APIStyle = %q, want ollama", cfg.APIStyle)
	}

	t.Setenv("MOE_LLM_BASE_URL", "http://override:11434/")
	t.Setenv("MOE_LLM_MODEL", " override-model ")
	t.Setenv("MOE_LLM_API_KEY", "env-key")
	cfg = Inference()
	if cfg.BaseURL != "http://override:11434" {
		t.Errorf("环境变量未生效或末尾斜杠未去除: BaseURL = %q", cfg.BaseURL)
	}
	if cfg.DefaultModel != "override-model" {
		t.Errorf("DefaultModel = %q, want override-model（应已去空格）", cfg.DefaultModel)
	}
	if cfg.APIKey != "env-key" {
		t.Errorf("APIKey = %q", cfg.APIKey)
	}
}

// TestInferenceOllamaFallback 验证 llm_inference 段缺失时回落历史 ollama 段。
func TestInferenceOllamaFallback(t *testing.T) {
	ResetForTest()
	t.Cleanup(ResetForTest)
	path := filepath.Join(t.TempDir(), "config.yaml")
	body := "ollama:\n  base_url: \"http://legacy:11434\"\n  api_style: ollama\n  timeout_seconds: 300\n  memory_model: \"legacy-model\"\n  api_key: \"legacy-key\"\n"
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadFile(path); err != nil {
		t.Fatal(err)
	}
	cfg := Inference()
	if cfg.BaseURL != "http://legacy:11434" || cfg.DefaultModel != "legacy-model" || cfg.APIKey != "legacy-key" {
		t.Errorf("ollama 回退未生效: %+v", cfg)
	}
	if cfg.Timeout.Seconds() != 300 {
		t.Errorf("Timeout = %v, want 300s", cfg.Timeout)
	}
}

// TestGameInference 复现 moeconfig.GameInferenceFromViper：
// game_base_url 为空时复用全局端点，非空时用独立端点且超时兜底 300。
func TestGameInference(t *testing.T) {
	loadFixture(t)
	cfg, model, mode := GameInference()
	if cfg.BaseURL != "http://127.0.0.1:6633" {
		t.Errorf("GameBaseURL 未生效: %q", cfg.BaseURL)
	}
	if mode != "narrator" {
		t.Errorf("mode = %q, want narrator", mode)
	}
	// game_model 留空 → 取端点模型列表，此处为空串
	if model != "" {
		t.Errorf("model = %q, want 空", model)
	}
	if cfg.Timeout.Seconds() != 120 {
		t.Errorf("Timeout = %v, want 120s（llm_inference.timeout_seconds）", cfg.Timeout)
	}
}

// TestContextTokens 与 apicomm.ContextLimitFromViper 一致，含 8192 兜底。
func TestContextTokens(t *testing.T) {
	loadFixture(t)
	if got := ContextTokens(); got != 32768 {
		t.Errorf("ContextTokens() = %d, want 32768", got)
	}

	ResetForTest()
	path := filepath.Join(t.TempDir(), "config.yaml")
	if err := os.WriteFile(path, []byte("runtime:\n  http_port: 1\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadFile(path); err != nil {
		t.Fatal(err)
	}
	if got := ContextTokens(); got != DefaultContextTokens {
		t.Errorf("未配置时 ContextTokens() = %d, want %d", got, DefaultContextTokens)
	}
}

// TestSecretPrecedence 固化两种**相反**的优先级：
// LLM / JWT 环境变量优先，OSS 密钥文件优先。这个不对称是迁移前就存在的，此处只做记录。
func TestSecretPrecedence(t *testing.T) {
	loadFixture(t)

	t.Setenv("MOE_AUTH_ACCESS_SECRET", "env-auth")
	t.Setenv("MOE_ADMIN_JWT_SECRET", "env-admin")
	if got := AuthAccessSecret(); got != "env-auth" {
		t.Errorf("AuthAccessSecret() = %q, want env-auth（环境变量应优先）", got)
	}
	secret, hours := AdminJWT()
	if secret != "env-admin" || hours != 168 {
		t.Errorf("AdminJWT() = (%q, %d), want (env-admin, 168)", secret, hours)
	}

	t.Setenv("MOE_OSS_ACCESS_KEY_ID", "env-ak")
	t.Setenv("MOE_OSS_ACCESS_KEY_SECRET", "env-sk")
	ak, sk := OSSCredentials()
	if ak != "file-ak" {
		t.Errorf("OSS AccessKeyID = %q, want file-ak（文件应优先于环境变量）", ak)
	}
	if sk != "env-sk" {
		t.Errorf("OSS AccessKeySecret = %q, want env-sk（文件为空时兜底环境变量）", sk)
	}
}

// TestDomainInProcess 是 IsSet 语义的关键用例：
// 「显式 false」必须返回 false，「未设置」才继承 single_process/api_in_process。
// 若改用类型化 bool 字段判定，vip 的 false 与未设置将无法区分。
func TestDomainInProcess(t *testing.T) {
	loadFixture(t)

	if !DomainInProcess("user") {
		t.Error("user 显式 true，应为 true")
	}
	if DomainInProcess("vip") {
		t.Error("vip 显式 false，应为 false（不能被默认值继承覆盖）")
	}
	// post 未在 fixture 中出现 → 继承 single_process||api_in_process = true
	if !DomainInProcess("post") {
		t.Error("post 未设置，应继承默认 true")
	}
	if !DefaultInProcessEnabled() {
		t.Error("DefaultInProcessEnabled() = false, want true")
	}
	if len(InProcessDomains()) != 19 {
		t.Errorf("InProcessDomains() 长度 = %d, want 19", len(InProcessDomains()))
	}
}

// TestDomainInProcessDefaultsFalse 验证全局闸关闭时未设置的域返回 false。
func TestDomainInProcessDefaultsFalse(t *testing.T) {
	ResetForTest()
	t.Cleanup(ResetForTest)
	path := filepath.Join(t.TempDir(), "config.yaml")
	if err := os.WriteFile(path, []byte("moe:\n  api_in_process: false\n  single_process: false\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadFile(path); err != nil {
		t.Fatal(err)
	}
	if DomainInProcess("post") {
		t.Error("全局闸关闭时未设置的域应为 false")
	}
	if DefaultInProcessEnabled() {
		t.Error("DefaultInProcessEnabled() = true, want false")
	}
}

// TestWechatLegacyFallback 守住历史扁平键回退链。
// 该链原先在 utils.wechatFlowCredentials，序6 迁移后只存在于 WechatFlowCredential。
func TestWechatLegacyFallback(t *testing.T) {
	loadFixture(t)

	id, secret, err := WechatFlowCredential("app")
	if err != nil {
		t.Fatalf("app flow: %v", err)
	}
	if id != "wx-app-id" || secret != "wx-app-secret" {
		t.Errorf("app = (%q, %q), want 结构化键优先", id, secret)
	}

	// website 结构化键为空 → 回退 wechat.web_app_id；secret 无处可取 → 报错
	_, _, err = WechatFlowCredential("website")
	if err == nil {
		t.Error("website secret 缺失，应报错而不是返回空凭证")
	}

	if _, _, err := WechatFlowCredential("bogus"); err == nil {
		t.Error("非法 flow 应报错")
	}
	if _, _, err := WechatFlowCredential("mobile"); err != nil {
		t.Errorf("mobile 应归一到 app: %v", err)
	}
}

// TestGetIsLenient 断言 Get 在读不到配置时返回零值而非 panic，
// 与迁移前各读取点「ReadInConfig 失败就用默认值」的行为一致。
func TestGetIsLenient(t *testing.T) {
	ResetForTest()
	t.Cleanup(ResetForTest)

	dir := t.TempDir()
	for _, sub := range []string{"config", "other/config", "other/other/config"} {
		if err := os.MkdirAll(filepath.Join(dir, sub), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// 切到一个三级都找不到 config.yaml 的目录（t.Chdir 会自动还原）
	t.Chdir(filepath.Join(dir, "other", "other"))

	c := Get()
	if c == nil {
		t.Fatal("Get() 返回 nil，应返回零值 Config")
	}
	if c.Runtime.HTTPPort != 0 {
		t.Errorf("HTTPPort = %d, want 0", c.Runtime.HTTPPort)
	}
	if Err() == nil {
		t.Error("Err() = nil, 应报告配置文件缺失")
	}
	if _, err := Load(); err == nil {
		t.Error("Load() 应返回错误，供启动路径感知")
	}
}

// TestRealConfigYAMLLoads 对仓库真实的 config.yaml 做一次冒烟：
// 能解析、端口与库名非空。文件缺失（如 CI 未挂载）时跳过。
func TestRealConfigYAMLLoads(t *testing.T) {
	path := filepath.Join("..", "..", "config", "config.yaml")
	if _, err := os.Stat(path); err != nil {
		t.Skipf("未找到 %s，跳过真实配置冒烟", path)
	}
	ResetForTest()
	t.Cleanup(ResetForTest)

	c, err := LoadFile(path)
	if err != nil {
		t.Fatalf("真实 config.yaml 解析失败: %v", err)
	}
	if c.Runtime.HTTPPort <= 0 {
		t.Errorf("runtime.http_port = %d, want > 0", c.Runtime.HTTPPort)
	}
	if c.Database.DBName == "" || c.Database.Host == "" {
		t.Errorf("database 段解析为空: %+v", c.Database)
	}
	if !c.Database.ParseTime {
		t.Error("database.parseTime 应为 true（驼峰键识别失败）")
	}
	// 这三个键是 #19 新加的。断言它们在真实文件里**确实解出了非零值**：
	// mapstructure tag 写错一个字母不会报错，只会静默拿到 0，
	// 于是「改了 yaml 但不生效」（§0 第 4 行那一类）会一路带到线上。
	if c.Moe.LifeTickSeconds <= 0 || c.Moe.LifeFlushSeconds <= 0 {
		t.Errorf("moe.life_tick_seconds/life_flush_seconds = %d/%d, want 均 > 0（键名或 tag 写错？）",
			c.Moe.LifeTickSeconds, c.Moe.LifeFlushSeconds)
	}
	if c.Moe.WorldTickSeconds <= 0 {
		t.Errorf("moe.world_tick_seconds = %d, want > 0（键名或 tag 写错？）", c.Moe.WorldTickSeconds)
	}
	if Path() == "" {
		t.Error("Path() 为空，应返回实际使用的绝对路径")
	}
}

// TestReload 验证写回后重读生效 —— 管理台 ApplyRuntimeConfigPatch 依赖这一点。
func TestReload(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.yaml")
	if err := os.WriteFile(path, []byte("runtime:\n  http_port: 8888\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	ResetForTest()
	t.Cleanup(ResetForTest)
	if _, err := LoadFile(path); err != nil {
		t.Fatal(err)
	}
	if got := Get().Runtime.HTTPPort; got != 8888 {
		t.Fatalf("初始 HTTPPort = %d", got)
	}

	if err := os.WriteFile(path, []byte("runtime:\n  http_port: 9000\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if got := Get().Runtime.HTTPPort; got != 8888 {
		t.Errorf("未 Reload 时 Get() 应仍返回缓存值 8888，got = %d", got)
	}
	if _, err := Reload(); err != nil {
		t.Fatalf("Reload 失败: %v", err)
	}
	if got := Get().Runtime.HTTPPort; got != 9000 {
		t.Errorf("Reload 后 HTTPPort = %d, want 9000", got)
	}
}

// TestReloadNeverExposesUnloadedWindow 固化 Reload 的原子性：重读期间并发的 Get 必须始终
// 看到 -f 指定的那个文件，既不能看到零值 Config，也不能看到 searchDirs 解析出的另一个文件。
//
// 判别力：把 Reload 改回「先在写锁内置 current=nil 再解锁、然后才 LoadFile」本测试就会失败。
// 关键在于 chdir 到一个深层临时目录 —— ./config、../config、../../config 三个候选都不存在，
// 于是窗口内的 loadLocked→resolvePath 必定失败，Get 返回 empty（Runtime.HTTPPort == 0），
// 读者立刻能观测到。旧窗口横跨一次完整读盘，因此 1000 轮 Reload 足以稳定命中。
func TestReloadNeverExposesUnloadedWindow(t *testing.T) {
	deep := filepath.Join(t.TempDir(), "a", "b", "c", "d")
	if err := os.MkdirAll(deep, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Chdir(deep)
	for _, dir := range searchDirs {
		if _, err := os.Stat(filepath.Join(dir, "config.yaml")); err == nil {
			t.Fatalf("前置条件不成立：%s/config.yaml 不该存在", dir)
		}
	}

	path := filepath.Join(t.TempDir(), "custom.yaml")
	if err := os.WriteFile(path, []byte("runtime:\n  http_port: 8888\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	ResetForTest()
	t.Cleanup(ResetForTest)
	if _, err := LoadFile(path); err != nil {
		t.Fatal(err)
	}
	if got := Get().Runtime.HTTPPort; got != 8888 {
		t.Fatalf("初始 HTTPPort = %d, want 8888", got)
	}

	stop := make(chan struct{})
	var wg sync.WaitGroup
	var bad atomic.Int64
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-stop:
					return
				default:
				}
				if got := Get().Runtime.HTTPPort; got != 8888 {
					bad.Add(1)
				}
			}
		}()
	}

	for i := 0; i < 1000; i++ {
		if _, err := Reload(); err != nil {
			close(stop)
			wg.Wait()
			t.Fatalf("第 %d 次 Reload 失败: %v", i, err)
		}
	}
	close(stop)
	wg.Wait()

	if n := bad.Load(); n > 0 {
		t.Errorf("Reload 期间有 %d 次 Get 读到了非 -f 文件的值（零值或 searchDirs 结果）", n)
	}
	if got := Get().Runtime.HTTPPort; got != 8888 {
		t.Errorf("1000 轮 Reload 后 HTTPPort = %d, want 8888", got)
	}
	if Path() == "" {
		t.Error("Reload 后 Path() 不应为空")
	}
}

// TestResolveInferenceIsRaw 固化 ResolveInference 与 Inference 的分界：前者是**原值**，
// 供 wiring/config_override.go 逐字段写回 apiconfig 片段。三个断言各对应一个
// 「解析版会改掉、写回时必须保留」的形状 —— 斜杠不去、风格不猜、超时不填兜底。
// 最后一条尤其要紧：若原值也返回 120，config_override 里 `if TimeoutSeconds > 0`
// 的守卫就会把文件没写的超时凭空写进片段。
func TestResolveInferenceIsRaw(t *testing.T) {
	loadBody(t, "llm_inference:\n  base_url: \"http://raw:11434/\"\n  api_style: \"\"\n  timeout_seconds: 0\n  memory_model: \" raw-model \"\n")

	r := ResolveInference()
	if r.BaseURL != "http://raw:11434/" {
		t.Errorf("BaseURL = %q, want 保留末尾斜杠", r.BaseURL)
	}
	if r.APIStyle != "" {
		t.Errorf("APIStyle = %q, want 空（原值不按 :11434 猜风格）", r.APIStyle)
	}
	if r.TimeoutSeconds != 0 {
		t.Errorf("TimeoutSeconds = %d, want 0（原值不填 120 兜底）", r.TimeoutSeconds)
	}
	if r.MemoryModel != "raw-model" {
		t.Errorf("MemoryModel = %q, want raw-model（两侧空格仍要去除）", r.MemoryModel)
	}

	p := Inference()
	if p.BaseURL != "http://raw:11434" {
		t.Errorf("Inference().BaseURL = %q, want 去掉末尾斜杠", p.BaseURL)
	}
	if string(p.APIStyle) != "ollama" {
		t.Errorf("Inference().APIStyle = %q, want ollama（按 :11434 推断）", p.APIStyle)
	}
	if p.Timeout.Seconds() != 120 {
		t.Errorf("Inference().Timeout = %v, want 120s 兜底", p.Timeout)
	}
}

// TestBotPostModelConfiguredStopsAtFileLayer 守住「只到文件层为止」这条契约。
// 关键断言是第三个：两级都空时必须返回空串，把决定权留给调用方注入的
// deps.Inference.DefaultModel（generate_test.go 就靠这个可注入性构造 Deps）。
// 若这里再兜 memory_model，注入值会被文件值悄悄盖掉。
func TestBotPostModelConfiguredStopsAtFileLayer(t *testing.T) {
	loadFixture(t)
	if got := BotPostModelConfigured(); got != "qwen2" {
		t.Errorf("BotPostModelConfigured() = %q, want qwen2", got)
	}

	loadBody(t, "moe:\n  bot_post_model: \"\"\nllm_inference:\n  chat_model: \"chat-model\"\n  memory_model: \"memory-model\"\n")
	if got := BotPostModelConfigured(); got != "chat-model" {
		t.Errorf("BotPostModelConfigured() = %q, want chat-model（bot_post_model 为空时回落）", got)
	}

	loadBody(t, "llm_inference:\n  memory_model: \"memory-model\"\n")
	if got := BotPostModelConfigured(); got != "" {
		t.Errorf("BotPostModelConfigured() = %q, want 空（不得回落 memory_model）", got)
	}
}

// TestTopicAnalyzeModel 与上一条形成对照：这条链**是**要落到 memory_model 的，
// 顺序与迁移前 brain/topic_analyze.go 的 loadTopicAnalyzeModelFromViper 逐条一致。
func TestTopicAnalyzeModel(t *testing.T) {
	loadBody(t, "llm_inference:\n  memory_model: \"memory-model\"\n")
	if got := TopicAnalyzeModel(); got != "memory-model" {
		t.Errorf("TopicAnalyzeModel() = %q, want memory-model", got)
	}

	loadBody(t, "moe:\n  topic_analyze_model: \"analyze-model\"\nllm_inference:\n  memory_model: \"memory-model\"\n")
	if got := TopicAnalyzeModel(); got != "analyze-model" {
		t.Errorf("TopicAnalyzeModel() = %q, want analyze-model（moe 段优先）", got)
	}
}

// TestSchedulersInheritTrueWhenUnset 验证两个调度器开关的「未设置即 true」语义。
// 类型化 bool 会把缺失当成 false，于是没写开关的部署会静默停掉 Bot 发帖与入梦 ——
// 这正是 inheritBool 走原始 viper 的理由。
func TestSchedulersInheritTrueWhenUnset(t *testing.T) {
	loadFixture(t)
	if en, tick := BotScheduler(); !en || tick != 60*time.Second {
		t.Errorf("BotScheduler() = (%v, %v), want (true, 60s)", en, tick)
	}
	if en, tick := DreamScheduler(); !en || tick != 300*time.Second {
		t.Errorf("DreamScheduler() = (%v, %v), want (true, 300s)", en, tick)
	}

	loadBody(t, "runtime:\n  http_port: 8888\n")
	if en, tick := BotScheduler(); !en || tick != 60*time.Second {
		t.Errorf("未设置时 BotScheduler() = (%v, %v), want (true, 60s)", en, tick)
	}
	if en, tick := DreamScheduler(); !en || tick != 300*time.Second {
		t.Errorf("未设置时 DreamScheduler() = (%v, %v), want (true, 300s)", en, tick)
	}

	loadBody(t, "moe:\n  bot_scheduler_enabled: false\n  bot_scheduler_tick_seconds: 15\n  dream_scheduler_enabled: false\n  dream_scheduler_tick_seconds: 900\n")
	if en, tick := BotScheduler(); en || tick != 15*time.Second {
		t.Errorf("显式 false 时 BotScheduler() = (%v, %v), want (false, 15s)", en, tick)
	}
	if en, tick := DreamScheduler(); en || tick != 900*time.Second {
		t.Errorf("显式 false 时 DreamScheduler() = (%v, %v), want (false, 900s)", en, tick)
	}

	// tick_seconds 写了非正数 → 保留缺省，不能被 0 冲成「立刻循环」
	loadBody(t, "moe:\n  bot_scheduler_tick_seconds: 0\n  dream_scheduler_tick_seconds: -5\n")
	if _, tick := BotScheduler(); tick != 60*time.Second {
		t.Errorf("tick_seconds=0 时 BotScheduler() tick = %v, want 60s", tick)
	}
	if _, tick := DreamScheduler(); tick != 300*time.Second {
		t.Errorf("tick_seconds=-5 时 DreamScheduler() tick = %v, want 300s", tick)
	}
}

// TestLifeIntervalsNeverFallThroughToBizDefault 钉住 #19 里最容易踩空的一处：
// LifeIntervals 未配置时**必须**给 300 秒，不能给 0。
//
// 给 0 看着无害，实际会让 lifeapp.engineConfig 的 `if > 0` 守卫放行
// lifebiz.DefaultConfig() 的 **5 秒** —— 生产世界节奏凭空快 60 倍，
// 而迁移前 moewiring 一直是显式传 300 把那个 5 秒盖掉的。
// 判别力：把 lifeInterval 的兜底改成 return 0，本测试立刻红。
func TestLifeIntervalsNeverFallThroughToBizDefault(t *testing.T) {
	loadBody(t, "runtime:\n  http_port: 8888\n")
	if tick, flush := LifeIntervals(); tick != 300*time.Second || flush != 300*time.Second {
		t.Errorf("未设置时 LifeIntervals() = (%v, %v), want (300s, 300s)；"+
			"若拿到 0 说明会穿透到 biz 层的 5 秒缺省", tick, flush)
	}

	loadBody(t, "moe:\n  life_tick_seconds: 0\n  life_flush_seconds: -5\n")
	if tick, flush := LifeIntervals(); tick != 300*time.Second || flush != 300*time.Second {
		t.Errorf("非正数时 LifeIntervals() = (%v, %v), want (300s, 300s)", tick, flush)
	}

	loadBody(t, "moe:\n  life_tick_seconds: 30\n  life_flush_seconds: 120\n")
	if tick, flush := LifeIntervals(); tick != 30*time.Second || flush != 120*time.Second {
		t.Errorf("已配置时 LifeIntervals() = (%v, %v), want (30s, 120s)", tick, flush)
	}
}

// TestWorldTickIntervalUnsetMeansZero 钉住与 LifeIntervals **相反**的契约：
// 这里未配置时返回 0，让 gamebiz.StartWorldRunner 的 `interval <= 0` 守卫去兜底。
// 45 秒只该有一份副本（biz 层的 defaultWorldTickInterval）；
// 若这里也返回 45s，就成了第三份，改一处忘另一处必然分叉。
// 判别力：把 WorldTickInterval 的兜底改成 45*time.Second，本测试立刻红。
func TestWorldTickIntervalUnsetMeansZero(t *testing.T) {
	loadBody(t, "runtime:\n  http_port: 8888\n")
	if got := WorldTickInterval(); got != 0 {
		t.Errorf("未设置时 WorldTickInterval() = %v, want 0（由 biz 层兜底，别在这里抄第二份 45s）", got)
	}

	loadBody(t, "moe:\n  world_tick_seconds: -1\n")
	if got := WorldTickInterval(); got != 0 {
		t.Errorf("负数时 WorldTickInterval() = %v, want 0", got)
	}

	loadBody(t, "moe:\n  world_tick_seconds: 90\n")
	if got := WorldTickInterval(); got != 90*time.Second {
		t.Errorf("已配置时 WorldTickInterval() = %v, want 90s", got)
	}
}

// TestSmartRetry 断言缺失时返回 (0, 0) 而不是兜底值 ——
// runtime.LoadSmartOpts 靠这个 0 判断「文件没写，保留 DefaultSmartOpts」。
func TestSmartRetry(t *testing.T) {
	loadFixture(t)
	if retry, minInterval := SmartRetry(); retry != 30 || minInterval != 2 {
		t.Errorf("SmartRetry() = (%d, %d), want (30, 2)", retry, minInterval)
	}

	loadBody(t, "runtime:\n  http_port: 8888\n")
	if retry, minInterval := SmartRetry(); retry != 0 || minInterval != 0 {
		t.Errorf("未设置时 SmartRetry() = (%d, %d), want (0, 0)", retry, minInterval)
	}
}

// TestLifeEngineEnabledInherits 覆盖 life_engine_enabled 的四种组合。
// 它不是 *_api_in_process 形状，DomainInProcess 拼不出来，但继承语义相同。
func TestLifeEngineEnabledInherits(t *testing.T) {
	loadFixture(t)
	if !LifeEngineEnabled() {
		t.Error("fixture 显式 true，LifeEngineEnabled() = false")
	}

	loadBody(t, "moe:\n  single_process: true\n")
	if !LifeEngineEnabled() {
		t.Error("未设置且全局闸开，LifeEngineEnabled() = false, want true")
	}

	loadBody(t, "moe:\n  single_process: false\n  api_in_process: false\n")
	if LifeEngineEnabled() {
		t.Error("未设置且全局闸关，LifeEngineEnabled() = true, want false")
	}

	loadBody(t, "moe:\n  single_process: true\n  life_engine_enabled: false\n")
	if LifeEngineEnabled() {
		t.Error("显式 false 不应被继承覆盖，LifeEngineEnabled() = true")
	}
}
