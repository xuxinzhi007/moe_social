package conf

import (
	"os"
	"path/filepath"
	"testing"
)

// fixture 覆盖迁移前 20 处读取点会碰到的全部形状：驼峰键（database.parseTime）、
// 字符串端口（moe.production.external_http_port）、列表（local_models.catalog）、
// 历史扁平键（wechat.mobile_app_id）、以及「显式 false」与「未设置」两种开关。
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

local_models:
  storage_dir: "data/local_models"
  catalog:
    - id: qwen2.5-0.5b-instruct-q4
      name: "Qwen2.5 0.5B 离线助手"
      filename: "qwen2.5-0.5b-instruct-q4_k_m.gguf"
      size_bytes: 0
      sha256: ""
      description: "轻量离线对话"
      parameters_b: 0.5
      recommended: true

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
	if len(c.LocalModels.Catalog) != 1 {
		t.Fatalf("LocalModels.Catalog 长度 = %d, want 1", len(c.LocalModels.Catalog))
	}
	if c.LocalModels.Catalog[0].ParametersB != 0.5 || !c.LocalModels.Catalog[0].Recommended {
		t.Errorf("Catalog[0] = %+v", c.LocalModels.Catalog[0])
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
