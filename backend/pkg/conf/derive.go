package conf

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"backend/pkg/llminference"
)

// 环境变量覆盖表。集中在这一处，是为了让「哪些配置能被环境变量改掉」有唯一答案 ——
// 迁移前这些 os.Getenv 散在 5 个包里，且优先级并不统一：
// LLM / JWT 是「环境变量优先」，OSS 密钥是「文件优先、环境变量兜底」。
const (
	envLLMBaseURL   = "MOE_LLM_BASE_URL"
	envLLMAPIStyle  = "MOE_LLM_API_STYLE"
	envLLMModel     = "MOE_LLM_MODEL"
	envLLMAPIKey    = "MOE_LLM_API_KEY"
	envAuthSecret   = "MOE_AUTH_ACCESS_SECRET"
	envAdminJWT     = "MOE_ADMIN_JWT_SECRET"
	envOSSKeyID     = "MOE_OSS_ACCESS_KEY_ID"
	envOSSKeySecret = "MOE_OSS_ACCESS_KEY_SECRET"
)

// DefaultContextTokens 是 llm_inference.context_tokens 缺失时的兜底，
// 与 apicomm.ContextLimitFromViper 保持一致。
const DefaultContextTokens = 8192

// Inference 解析统一推理端点：环境变量 → llm_inference.* → ollama.*（历史键位）。
//
// ⚠️ 行为合并提示：迁移前有两个同职能读取点，回退链并不一致 ——
// moeconfig.InferenceFromViper 认全部 4 个 MOE_LLM_* 环境变量，
// runtime.LoadInferenceFromViper 只认 MOE_LLM_API_KEY。
// 本方法取超集（认全部 4 个）。runtime 侧迁移过来后，设置 MOE_LLM_BASE_URL /
// MOE_LLM_API_STYLE / MOE_LLM_MODEL 将开始对 Bot 调度生效，这是有意的收敛。
func Inference() llminference.Config {
	c := Get().LLMInference
	o := Get().Ollama
	return llminference.ConfigFrom(
		firstNonEmpty(env(envLLMBaseURL), c.BaseURL, o.BaseURL),
		firstNonEmpty(env(envLLMAPIStyle), c.APIStyle, o.APIStyle),
		firstPositiveInt(c.TimeoutSeconds, o.TimeoutSeconds),
		firstNonEmpty(env(envLLMModel), c.MemoryModel, o.MemoryModel),
		firstNonEmpty(env(envLLMAPIKey), c.APIKey, o.APIKey),
	)
}

// GameInference 文字游戏专用端点：game_base_url 留空时复用 Inference。
// 返回值与 moeconfig.GameInferenceFromViper 一致（配置、模型、narrator|agent 模式）。
func GameInference() (llminference.Config, string, string) {
	global := Inference()
	c := Get().LLMInference

	gameModel := strings.TrimSpace(c.GameModel)
	gameMode := strings.TrimSpace(c.GameLLMMode)
	if strings.TrimSpace(c.GameBaseURL) == "" {
		return global, firstNonEmpty(gameModel, global.DefaultModel), gameMode
	}
	style := c.APIStyle
	if strings.TrimSpace(style) == "" {
		style = "openai"
	}
	timeout := c.TimeoutSeconds
	if timeout <= 0 {
		timeout = 300
	}
	return llminference.ConfigFrom(c.GameBaseURL, style, timeout, gameModel, ""), gameModel, gameMode
}

// ContextTokens 推理上下文长度兜底值。
func ContextTokens() int {
	if n := Get().LLMInference.ContextTokens; n > 0 {
		return n
	}
	return DefaultContextTokens
}

// BotPostModel Bot 发帖模型：moe.bot_post_model → llm_inference.chat_model → 统一 memory_model。
// runtime.resolvePostModel 在此之后还有两级兜底（agent runtime 的 model_name、硬编码 "qwen2"），
// 那两级要调用方传入运行时数据，故意留在那里。
func BotPostModel() string {
	return firstNonEmpty(Get().Moe.BotPostModel, Get().LLMInference.ChatModel, Inference().DefaultModel)
}

// TopicAnalyzeModel 话题分析模型：moe.topic_analyze_model → llm_inference.memory_model。
func TopicAnalyzeModel() string {
	return firstNonEmpty(Get().Moe.TopicAnalyzeModel, Get().LLMInference.MemoryModel)
}

// AuthAccessSecret App JWT 密钥：MOE_AUTH_ACCESS_SECRET 优先。
// 为空时进程照常启动，签名/校验会在每次请求时报 "jwt not configured"。
func AuthAccessSecret() string {
	return firstNonEmpty(env(envAuthSecret), Get().Auth.AccessSecret)
}

// AdminJWT 管理台 JWT 密钥与有效期（小时）：MOE_ADMIN_JWT_SECRET 优先，
// 有效期缺省 24 小时（与 wiring.ApplyUnifiedConfigOverrides 一致）。
func AdminJWT() (secret string, expireHours int64) {
	secret = firstNonEmpty(env(envAdminJWT), Get().Admin.JWTSecret)
	expireHours = Get().Admin.TokenExpireHours
	if expireHours <= 0 {
		expireHours = 24
	}
	return secret, expireHours
}

// OSSCredentials 阿里云 OSS 密钥。
// ⚠️ 与 LLM / JWT 相反：这里文件优先、环境变量兜底（沿用 store_oss.go 的顺序）。
func OSSCredentials() (accessKeyID, accessKeySecret string) {
	oss := Get().Image.OSS
	accessKeyID = firstNonEmpty(oss.AccessKeyID, env(envOSSKeyID))
	accessKeySecret = firstNonEmpty(oss.AccessKeySecret, env(envOSSKeySecret))
	return accessKeyID, accessKeySecret
}

// DSN 组装 MySQL 连接串，与 utils/db.go 的格式逐字段一致。
func DSN() string {
	d := Get().Database
	return fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=%s&parseTime=%t&loc=%s",
		d.User, d.Password, d.Host, d.Port, d.DBName, d.Charset, d.ParseTime, d.Loc)
}

// HTTPPort 对外监听端口：runtime.http_port → moe.production.external_http_port（字符串）。
// 两者都缺失时返回 0，由调用方决定兜底（与 moesocial.httpPortFromUnified 一致）。
func HTTPPort() int {
	if p := Get().Runtime.HTTPPort; p > 0 {
		return p
	}
	if s := strings.TrimSpace(Get().Moe.Production.ExternalHTTPPort); s != "" {
		if p, err := strconv.Atoi(s); err == nil && p > 0 {
			return p
		}
	}
	return 0
}

// PublicBaseURL 对外 API 根：api.public_base_url → app_client.public_api_base_url。
// 已去除末尾斜杠，可直接拼路径。
func PublicBaseURL() string {
	return trimURL(firstNonEmpty(Get().API.PublicBaseURL, Get().AppClient.PublicAPIBaseURL))
}

// ImagePublicBaseURL 图片外链根；为空时回落 PublicBaseURL。
func ImagePublicBaseURL() string {
	if u := trimURL(Get().Image.PublicBaseURL); u != "" {
		return u
	}
	return PublicBaseURL()
}

// FeishuRedirectURI 飞书 OAuth 回调：feishu.redirect_uri 留空时由 PublicBaseURL 拼出。
func FeishuRedirectURI() string {
	if u := strings.TrimSpace(Get().Feishu.RedirectURI); u != "" {
		return u
	}
	if base := PublicBaseURL(); base != "" {
		return base + "/api/auth/feishu/callback"
	}
	return ""
}

// WechatRedirectURI 微信 OAuth 回调，规则同 FeishuRedirectURI。
func WechatRedirectURI() string {
	if u := strings.TrimSpace(Get().Wechat.RedirectURI); u != "" {
		return u
	}
	if base := PublicBaseURL(); base != "" {
		return base + "/api/auth/wechat/callback"
	}
	return ""
}

// WechatFlowCredential 按 flow（app | website | mp）取凭证，保留迁移前的历史扁平键回退：
// app 额外认 wechat.mobile_app_id / wechat.mobile.app_id，website 认 wechat.web_app_id，
// mp 认 wechat.mp_app_id / wechat.app_id。flow 非法时返回空凭证与错误。
func WechatFlowCredential(flow string) (appID, appSecret string, err error) {
	w := Get().Wechat
	switch strings.ToLower(strings.TrimSpace(flow)) {
	case "app", "mobile":
		appID = firstNonEmpty(w.App.AppID, legacy("wechat.mobile_app_id"), legacy("wechat.mobile.app_id"))
		appSecret = firstNonEmpty(w.App.AppSecret, legacy("wechat.mobile_app_secret"), legacy("wechat.mobile.app_secret"))
		// 勿回退 mp：移动应用 code 只能用 wechat.app 凭证换取，混用会报 10005。
	case "website", "qr", "scan":
		appID = firstNonEmpty(w.Website.AppID, legacy("wechat.web_app_id"))
		appSecret = firstNonEmpty(w.Website.AppSecret, legacy("wechat.web_app_secret"))
	case "mp", "oa", "official":
		appID = firstNonEmpty(w.MP.AppID, legacy("wechat.mp_app_id"), legacy("wechat.app_id"))
		appSecret = firstNonEmpty(w.MP.AppSecret, legacy("wechat.mp_app_secret"), legacy("wechat.app_secret"))
	default:
		return "", "", fmt.Errorf("conf: 未知的微信 flow %q", flow)
	}
	if appID == "" || appSecret == "" {
		return "", "", fmt.Errorf("conf: wechat %s 凭证缺失（config.yaml）", flow)
	}
	return appID, appSecret, nil
}

// inProcessDomains 是 moe.<domain>_api_in_process 的 19 个同形开关。
// 用域名拼键而不是 19 个结构体字段，是因为它们的语义完全一致：未设置即继承默认。
// moe.api_in_process 不在这一族里（它是全局闸，键形不带 domain 前缀），单独由
// Config.Moe.APIInProcess 承载。
var inProcessDomains = []string{
	"user", "vip", "landing", "behavior", "post", "comment", "checkin",
	"achievement", "gift", "battle", "llm", "ai", "community", "chat",
	"admin_readonly", "companion", "game", "life", "notify",
}

// DefaultInProcessEnabled 各域开关未显式设置时的继承值：moe.single_process || moe.api_in_process。
func DefaultInProcessEnabled() bool {
	return Get().Moe.SingleProcess || Get().Moe.APIInProcess
}

// DomainInProcess 报告某域是否走进程内装配（moewiring.domainInProcessEnabled 的等价实现）。
// 键未设置时继承 DefaultInProcessEnabled，而不是取 false —— 这个区别是 IsSet 存在的理由。
func DomainInProcess(domain string) bool {
	key := "moe." + strings.TrimSpace(domain) + "_api_in_process"
	if IsSet(key) {
		return domainBool(key)
	}
	return DefaultInProcessEnabled()
}

// InProcessDomains 返回全部受开关控制的域名，供装配处遍历或自检。
func InProcessDomains() []string {
	out := make([]string, len(inProcessDomains))
	copy(out, inProcessDomains)
	return out
}

func domainBool(key string) bool {
	Get()
	mu.RLock()
	s := current
	mu.RUnlock()
	if s == nil || s.v == nil {
		return false
	}
	return s.v.GetBool(key)
}

// legacy 读取未被 Config 建模的历史扁平键（如 wechat.mobile_app_id）。
func legacy(key string) string {
	Get()
	mu.RLock()
	s := current
	mu.RUnlock()
	if s == nil || s.v == nil {
		return ""
	}
	return strings.TrimSpace(s.v.GetString(key))
}

func env(key string) string {
	return strings.TrimSpace(os.Getenv(key))
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

func firstPositiveInt(values ...int) int {
	for _, v := range values {
		if v > 0 {
			return v
		}
	}
	return 0
}

func trimURL(u string) string {
	u = strings.TrimSpace(u)
	for strings.HasSuffix(u, "/") {
		u = strings.TrimSuffix(u, "/")
	}
	return u
}
