package conf

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

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

// DefaultContextTokens 是 llm_inference.context_tokens 缺失时的兜底。
// 迁移前这个 8192 在 apicomm 与 brain 两处各写了一遍，现在只有这一处。
const DefaultContextTokens = 8192

// defaultLifeInterval 是 moe.life_tick_seconds / life_flush_seconds 缺失时的兜底。
// 迁移前它是 moewiring/api_life.go 的编译期常量 livingWorldIntervalSeconds = 5*60。
//
// 别和 lifebiz.DefaultConfig() 里的 5 秒搞混：那个是单元测试用的引擎缺省，
// 生产路径从来都是被这里显式盖掉的 —— 详见 LifeIntervals 的注释。
const defaultLifeInterval = 5 * time.Minute

// RawInference 是 llm_inference 段套用 MOE_LLM_* 覆盖后的**原值**：api_style 还是
// "ollama"/"openai" 这样的字面量，超时还是秒数，都没经过 llminference 的解析。
// wiring/config_override.go 要把这些原样写回 apiconfig 片段，用的是这个形状；
// Inference() 是它的解析版。
type RawInference struct {
	BaseURL        string
	APIStyle       string
	TimeoutSeconds int
	MemoryModel    string
	APIKey         string
}

// ResolveInference 解析统一推理端点的原值：环境变量 → llm_inference.* → ollama.*（历史键位）。
//
// ⚠️ 行为合并提示：迁移前有两个同职能读取点，回退链并不一致 ——
// moeconfig.InferenceFromViper 认全部 4 个 MOE_LLM_* 环境变量，
// runtime.LoadInferenceFromViper 只认 MOE_LLM_API_KEY。
// 本方法取超集（认全部 4 个）。两处都收敛到这里之后，设置 MOE_LLM_BASE_URL /
// MOE_LLM_API_STYLE / MOE_LLM_MODEL 也开始对 Bot 调度生效（此前只影响记忆抽取与 Companion）。
// 这是有意的收敛：那三个变量的唯一设置处是 backend/docker-compose.binary.yml:10-12，
// 默认值都是空串；运维真去设它，意图就是把整个 LLM 端点搬走，
// 让 Bot 调度继续连旧端点才是错的（§12.1「同一件事两条链」）。
func ResolveInference() RawInference {
	c := Get().LLMInference
	o := Get().Ollama
	return RawInference{
		BaseURL:        firstNonEmpty(env(envLLMBaseURL), c.BaseURL, o.BaseURL),
		APIStyle:       firstNonEmpty(env(envLLMAPIStyle), c.APIStyle, o.APIStyle),
		TimeoutSeconds: firstPositiveInt(c.TimeoutSeconds, o.TimeoutSeconds),
		MemoryModel:    firstNonEmpty(env(envLLMModel), c.MemoryModel, o.MemoryModel),
		APIKey:         firstNonEmpty(env(envLLMAPIKey), c.APIKey, o.APIKey),
	}
}

// Inference 是 ResolveInference 的解析版，供 llminference.Chat 直接使用。
func Inference() llminference.Config {
	r := ResolveInference()
	return llminference.ConfigFrom(r.BaseURL, r.APIStyle, r.TimeoutSeconds, r.MemoryModel, r.APIKey)
}

// GameInference 文字游戏专用端点：game_base_url 留空时复用 Inference。
// 返回（配置、模型、narrator|agent 模式）；取值与迁移前的
// moeconfig.GameInferenceFromViper 逐条一致，含 api_style 空→openai、超时 ≤0→300 两个兜底。
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

// BotPostModelConfigured Bot 发帖模型的文件层：moe.bot_post_model → llm_inference.chat_model。
//
// 故意**不**接 Inference().DefaultModel 那一级：两个调用方（runtime.resolvePostModel、
// brain.resolveRefineModel）紧接着就查各自的 deps.Inference.DefaultModel，
// 那是调用方注入的运行时数据。在这里再兜一遍会把注入值悄悄盖掉。
// 迁移前这两处各有一个同名 loadBotPostModelFromViper，回退链还不一致
// （runtime 认 chat_model，brain 不认），现已统一到本方法。
func BotPostModelConfigured() string {
	return firstNonEmpty(Get().Moe.BotPostModel, Get().LLMInference.ChatModel)
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
	if u := TrimURL(Get().API.PublicBaseURL); u != "" {
		return u
	}
	return TrimURL(Get().AppClient.PublicAPIBaseURL)
}

// ClientPublicBaseURL 客户端 API 根：显式 app_client 覆盖 → PublicBaseURL。
func ClientPublicBaseURL() string {
	if u := TrimURL(Get().AppClient.PublicAPIBaseURL); u != "" {
		return u
	}
	return PublicBaseURL()
}

// ImagePublicBaseURL 图片外链根；为空时回落 PublicBaseURL。
func ImagePublicBaseURL() string {
	if u := TrimURL(Get().Image.PublicBaseURL); u != "" {
		return u
	}
	return PublicBaseURL()
}

// FeishuRedirectURI 飞书 OAuth 回调：feishu.redirect_uri 留空时由 PublicBaseURL 拼出。
func FeishuRedirectURI() string {
	if u := strings.TrimSpace(Get().Feishu.RedirectURI); TrimURL(u) != "" {
		return u
	}
	if base := PublicBaseURL(); base != "" {
		return base + "/api/auth/feishu/callback"
	}
	return ""
}

// WechatRedirectURI 微信 OAuth 回调，规则同 FeishuRedirectURI。
func WechatRedirectURI() string {
	if u := strings.TrimSpace(Get().Wechat.RedirectURI); TrimURL(u) != "" {
		return u
	}
	if base := PublicBaseURL(); base != "" {
		return base + "/api/auth/wechat/callback"
	}
	return ""
}

// DefaultOAuthAuthTTL / DefaultOAuthTicketTTL / DefaultOAuthMaxPendingAuths
// 是 oauth.* 未配置时的兜底。授权事务给 10 分钟（用户可能在供应商页面停留、
// 或在手机上切到飞书/微信 App 再回来）；ticket 只活 60 秒 —— 它的唯一用途是
// 把浏览器 302 落地和紧随其后的 login 请求接上，窗口越短重放面越小。
const (
	DefaultOAuthAuthTTL        = 10 * time.Minute
	DefaultOAuthTicketTTL      = 60 * time.Second
	DefaultOAuthMaxPendingAuth = 4096
)

// OAuthAllowedReturnURLs 精确回跳白名单：逐项 TrimURL 规范化、丢弃空项、按首次出现去重。
//
// 规范化只做「去首尾空白 + 去末尾斜杠」，不做大小写折叠、不补默认端口、不解析重排 ——
// 匹配方（internal/oauthflow）对客户端提交的 return_url 施加完全相同的规范化，
// 两边一致就够了；在这里多做一步反而会让「配置里写的」和「实际放行的」产生分歧。
func OAuthAllowedReturnURLs() []string {
	raw := Get().OAuth.AllowedReturnURLs
	out := make([]string, 0, len(raw))
	seen := make(map[string]struct{}, len(raw))
	for _, item := range raw {
		u := TrimURL(item)
		if u == "" {
			continue
		}
		if _, dup := seen[u]; dup {
			continue
		}
		seen[u] = struct{}{}
		out = append(out, u)
	}
	return out
}

// OAuthAuthTTL 授权事务（服务端 state）有效期；非正数回落 DefaultOAuthAuthTTL。
func OAuthAuthTTL() time.Duration {
	return oauthTTL(Get().OAuth.AuthTTLSeconds, DefaultOAuthAuthTTL)
}

// OAuthTicketTTL 一次性 ticket 有效期；非正数回落 DefaultOAuthTicketTTL。
func OAuthTicketTTL() time.Duration {
	return oauthTTL(Get().OAuth.TicketTTLSeconds, DefaultOAuthTicketTTL)
}

func oauthTTL(seconds int64, def time.Duration) time.Duration {
	if seconds > 0 {
		return time.Duration(seconds) * time.Second
	}
	return def
}

// OAuthMaxPendingAuths 待处理授权事务容量上限；非正数回落 DefaultOAuthMaxPendingAuth。
func OAuthMaxPendingAuths() int {
	if n := Get().OAuth.MaxPendingAuths; n > 0 {
		return n
	}
	return DefaultOAuthMaxPendingAuth
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
	return inheritBool("moe."+strings.TrimSpace(domain)+"_api_in_process", DefaultInProcessEnabled())
}

// LifeEngineEnabled 报告 moe.life_engine_enabled。
// 它不是 *_api_in_process 形状，DomainInProcess 拼不出来，但继承语义完全相同：
// 迁移前 moewiring/api_life.go 就是把它和 moe.life_api_in_process 一起丢给
// domainInProcessEnabled 的，未设置时同样继承全局闸。
func LifeEngineEnabled() bool {
	return inheritBool("moe.life_engine_enabled", DefaultInProcessEnabled())
}

// BotScheduler Bot 发帖调度器：moe.bot_scheduler_enabled **未设置时为 true**（不是 false），
// tick 缺省 60 秒。与迁移前 runtime.LoadSchedulerOptsFromViper 的取值逐条一致。
func BotScheduler() (enabled bool, tick time.Duration) {
	enabled = inheritBool("moe.bot_scheduler_enabled", true)
	tick = 60 * time.Second
	if s := Get().Moe.BotSchedulerTickSeconds; s > 0 {
		tick = time.Duration(s) * time.Second
	}
	return enabled, tick
}

// DreamScheduler 入梦调度器：moe.dream_scheduler_enabled 未设置时为 true，tick 缺省 300 秒。
func DreamScheduler() (enabled bool, tick time.Duration) {
	enabled = inheritBool("moe.dream_scheduler_enabled", true)
	tick = 300 * time.Second
	if s := Get().Moe.DreamSchedulerTickSeconds; s > 0 {
		tick = time.Duration(s) * time.Second
	}
	return enabled, tick
}

// LifeIntervals Life 引擎的 tick / flush 间隔，缺省各 300 秒。
//
// 缺省值必须留在这里、不能返回 0 让下游兜底：lifebiz.DefaultConfig() 的
// TickInterval/FlushInterval 是 **5 秒**，而生产路径一直是 moewiring 显式传 300 秒把它盖掉。
// 若这里未配置时返回 0，lifeapp.engineConfig 的 `if > 0` 守卫会放行那个 5 秒 ——
// 世界节奏凭空快 60 倍。所以 300 是这里的缺省，biz 层的 5 秒继续只服务于单元测试。
//
// 非正数（含未设置）都回落到缺省，与 engineConfig 的守卫同语义。
func LifeIntervals() (tick, flush time.Duration) {
	return lifeInterval(Get().Moe.LifeTickSeconds), lifeInterval(Get().Moe.LifeFlushSeconds)
}

func lifeInterval(seconds int64) time.Duration {
	if seconds > 0 {
		return time.Duration(seconds) * time.Second
	}
	return defaultLifeInterval
}

// WorldTickInterval game 后台世界时钟的间隔；**未配置时返回 0**，
// 由 gamebiz.StartWorldRunner 的 `interval <= 0` 守卫回落到 defaultWorldTickInterval。
// 45 秒这个数只该有一份副本，就在 biz 层。
//
// 迁移前它有两份：gamebiz.defaultWorldTickInterval 与 service/game 调用点里硬写的
// 45*time.Second —— 后者恰好等于前者，于是那个守卫分支永远走不到，改一处忘另一处就分叉。
func WorldTickInterval() time.Duration {
	if s := Get().Moe.WorldTickSeconds; s > 0 {
		return time.Duration(s) * time.Second
	}
	return 0
}

// SmartRetry 智能发送间隔（分钟）与最小间隔（小时）。返回 0 表示文件里没写或写了非正数，
// 由调用方保留自身默认 —— 与迁移前 runtime.LoadSmartOptsFromViper 的 `if m > 0` 一致。
func SmartRetry() (retryMinutes, minIntervalHours int) {
	return Get().Moe.BotSmartRetryMinutes, Get().Moe.BotSmartMinIntervalHours
}

// InProcessDomains 返回全部受开关控制的域名，供装配处遍历或自检。
func InProcessDomains() []string {
	out := make([]string, len(inProcessDomains))
	copy(out, inProcessDomains)
	return out
}

// inheritBool 读取「未设置即继承」语义的布尔键：IsSet 才取值，否则用 def。
// 类型化字段表达不了这个区别（未设置和显式 false 都是 false），所以这几个键走原始 viper。
func inheritBool(key string, def bool) bool {
	if IsSet(key) {
		return domainBool(key)
	}
	return def
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

// TrimURL 去掉首尾空白与末尾斜杠；纯斜杠视为空，调用方再决定回退。
func TrimURL(u string) string {
	u = strings.TrimSpace(u)
	for strings.HasSuffix(u, "/") {
		u = strings.TrimSuffix(u, "/")
	}
	return u
}
