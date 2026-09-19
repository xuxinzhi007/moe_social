// Package conf 统一加载 backend/config/config.yaml，为全仓提供单一配置读取入口。
//
// 迁移前同一份 config.yaml 被 19 处独立读取点各自打开（18 个 viper.New() + utils.InitConfig() 全局单例）：
// 每处硬编码一遍搜索路径、各自实现一遍回退链与环境变量覆盖，键名写错不会报错、只会静默取到零值。
// 本包把这些收敛成：一次加载 + 类型化结构（config.go）+ 解析方法（derive.go）。
//
// 新增配置项：在 config.go 加字段（mapstructure tag = YAML 键名）；
// 若该项需要环境变量覆盖或历史键回退，在 derive.go 加一个方法。
package conf

// Config 是 backend/config/config.yaml 的类型化镜像。
//
// 字段只反映文件内容本身。环境变量覆盖与历史键回退（如 wechat.app→wechat.mobile_app_id）
// 一律走 derive.go 的方法，不要在字段上叠默认值，
// 否则「文件里没写」和「文件里写了 false/0」会分不清。
//
// 以下 config.yaml 里存在的段落**故意没有建模**，因为全仓没有任何 Go 代码读它们
// （逐个 grep 确认过，不是漏掉）：
//   - server.port / server.host —— 单进程化后端口只认 runtime.http_port，8080 无监听者
//   - memory.search.* / memory.embedding.* —— 记忆检索当前走关键词，向量/图谱段是死配置
//   - moe.enabled / moe.default_capability_tier / moe.bot_post_daily_limit_default
//     / moe.production.unified_entry
//     （moe.enabled 是 2026-09-09 序2 批次补记的：全仓 Go 与非 Go 均零引用；
//     unified_entry 于 2026-09-11 随 MoeProduction 的另三个 gRPC/pilot 端口字段一并摘除）
//   - temp_mail.api_key（mail.tm 无需鉴权）
//
// api.super_rpc_endpoints / api.super_rpc_timeout_ms 曾在此列，2026-09-08 已从 config.yaml 删除：
// go-zero RPC 进程随 Kratos 单进程迁移移除后二者零读者，而原注释还在指导运维设置
// 同样无人消费的 MOE_SUPER_RPC_ENDPOINT。另一个键 moe.pilot.super_rpc_endpoint 原由
// moeconf/load.go 读取，该包已于 2026-09-09 整包删除，承载它的 MoePilot 一并移除
// （且 moe.pilot 段在 config.yaml 里从来不存在，那处读取一直是零值）。
//
// 需要时再加字段；加之前先确认它真的有读者，别再往文件里堆死配置。
type Config struct {
	Runtime        Runtime        `mapstructure:"runtime"`
	Auth           Auth           `mapstructure:"auth"`
	Admin          Admin          `mapstructure:"admin"`
	API            API            `mapstructure:"api"`
	Database       Database       `mapstructure:"database"`
	Image          Image          `mapstructure:"image"`
	AppClient      AppClient      `mapstructure:"app_client"`
	LLMInference   LLMInference   `mapstructure:"llm_inference"`
	Ollama         Ollama         `mapstructure:"ollama"`
	TempMail       TempMail       `mapstructure:"temp_mail"`
	PrivateMessage PrivateMessage `mapstructure:"private_message"`
	Feishu         Feishu         `mapstructure:"feishu"`
	Wechat         Wechat         `mapstructure:"wechat"`
	OAuth          OAuth          `mapstructure:"oauth"`
	Agora          Agora          `mapstructure:"agora"`
	Moe            Moe            `mapstructure:"moe"`
}

// OAuth 第三方登录（飞书 / 微信）的授权事务参数。
//
// AllowedReturnURLs 是**精确**回跳白名单：授权成功后服务端只会 302 到这份列表里的地址，
// 客户端提交的 return_url 必须与其中一项规范化后完全相等（scheme/host/port/path 全等，
// 不接受 userinfo、query、fragment，不接受 http/https/moesocial 以外的协议）。
//
// 换开发机、换隧道就改这份列表 —— 不要放宽成「信任 API origin」「信任任意 localhost /
// 局域网 / 隧道域名」或「拿 state 当回跳地址」。那三种做法正是 #50 修掉的开放重定向：
// 攻击者构造一个 state 指向自己站点，服务端就会把用户的授权码 302 送过去。
type OAuth struct {
	AllowedReturnURLs []string `mapstructure:"allowed_return_urls"`
	// AuthTTLSeconds 授权事务（服务端 state）有效期，缺省 600 秒。
	AuthTTLSeconds int64 `mapstructure:"auth_ttl_seconds"`
	// TicketTTLSeconds 回调签发的一次性 ticket 有效期，缺省 60 秒。
	TicketTTLSeconds int64 `mapstructure:"ticket_ttl_seconds"`
	// MaxPendingAuths 内存中并存的授权事务上限，缺省 4096；满时淘汰最早到期的一条。
	MaxPendingAuths int `mapstructure:"max_pending_auths"`
}

// Agora RTC 凭证；缺失键保留 API 片段值，显式空值禁用对应凭证。
type Agora struct {
	AppID          string `mapstructure:"app_id"`
	AppCertificate string `mapstructure:"app_certificate"`
}

// Runtime 进程运行时（对外端口、启动片段路径）。
type Runtime struct {
	HTTPHost string `mapstructure:"http_host"`
	HTTPPort int    `mapstructure:"http_port"`
	// HandDrawRequireModeration 手绘是否强制过审，由 moewiring/api_post.go 读取。
	HandDrawRequireModeration bool   `mapstructure:"hand_draw_require_moderation"`
	APIConfigFragment         string `mapstructure:"api_config_fragment"`
}

// Auth App 端 JWT。缺失不会导致启动失败：utils/auth_jwt_config.go 在每次请求时才报错。
type Auth struct {
	AccessSecret        string `mapstructure:"access_secret"`
	AccessExpireSeconds int64  `mapstructure:"access_expire_seconds"`
}

// Admin 管理台 JWT 与首启账号（与 App JWT 分离）。
type Admin struct {
	JWTSecret        string `mapstructure:"jwt_secret"`
	TokenExpireHours int64  `mapstructure:"token_expire_hours"`
	Bootstrap        struct {
		Username string `mapstructure:"username"`
		Password string `mapstructure:"password"`
	} `mapstructure:"bootstrap"`
}

// API 对外根地址。
type API struct {
	PublicBaseURL string `mapstructure:"public_base_url"`
}

// Database MySQL 连接。当前指向测试库（开发便利，非生产数据）。
type Database struct {
	Host      string `mapstructure:"host"`
	Port      int    `mapstructure:"port"`
	User      string `mapstructure:"user"`
	Password  string `mapstructure:"password"`
	DBName    string `mapstructure:"dbname"`
	Charset   string `mapstructure:"charset"`
	ParseTime bool   `mapstructure:"parsetime"`
	Loc       string `mapstructure:"loc"`
}

// Image 图片存储：driver=local 落盘，driver=oss 走阿里云。
type Image struct {
	Driver        string   `mapstructure:"driver"`
	LocalDir      string   `mapstructure:"local_dir"`
	PublicBaseURL string   `mapstructure:"public_base_url"`
	MaxBytes      int64    `mapstructure:"max_bytes"`
	OSS           ImageOSS `mapstructure:"oss"`
}

// ImageOSS 阿里云对象存储。密钥优先取 MOE_OSS_ACCESS_KEY_ID / MOE_OSS_ACCESS_KEY_SECRET。
type ImageOSS struct {
	Endpoint        string `mapstructure:"endpoint"`
	Bucket          string `mapstructure:"bucket"`
	AccessKeyID     string `mapstructure:"access_key_id"`
	AccessKeySecret string `mapstructure:"access_key_secret"`
	Prefix          string `mapstructure:"prefix"`
	PublicBaseURL   string `mapstructure:"public_base_url"`
	Region          string `mapstructure:"region"`
	ProxyViaAPI     bool   `mapstructure:"proxy_via_api"`
}

// AppClient GET /api/public/client-config 返回给旧版 App 的公网根。
type AppClient struct {
	PublicAPIBaseURL string `mapstructure:"public_api_base_url"`
}

// LLMInference 统一推理端点（Moe Bot / Companion / 记忆共用）。
// ModelManagement controls single-process derived-model writes and allowed bases.
type ModelManagement struct {
	AllowedBaseModels       []string `mapstructure:"allowed_base_models"`
	UserQuota               int      `mapstructure:"user_quota"`
	GlobalQuota             int      `mapstructure:"global_quota"`
	WriteConcurrency        int      `mapstructure:"write_concurrency"`
	ModelSyncTimeoutSeconds int      `mapstructure:"model_sync_timeout_seconds"`
}

type LLMInference struct {
	ModelManagement ModelManagement `mapstructure:"model_management"`
	Provider        string          `mapstructure:"provider"`
	BaseURL         string          `mapstructure:"base_url"`
	APIStyle        string          `mapstructure:"api_style"`
	TimeoutSeconds  int             `mapstructure:"timeout_seconds"`
	MemoryModel     string          `mapstructure:"memory_model"`
	ChatModel       string          `mapstructure:"chat_model"`
	APIKey          string          `mapstructure:"api_key"`
	GameBaseURL     string          `mapstructure:"game_base_url"`
	GameModel       string          `mapstructure:"game_model"`
	GameLLMMode     string          `mapstructure:"game_llm_mode"`
	ContextTokens   int             `mapstructure:"context_tokens"`
}

// Ollama 历史键位。当前 config.yaml 中整段被注释，仅作为 llm_inference 的回退保留；
// 确认无线上副本依赖后可连同 derive.go 里的 12 处回退一起删除。
type Ollama struct {
	BaseURL        string `mapstructure:"base_url"`
	APIStyle       string `mapstructure:"api_style"`
	TimeoutSeconds int    `mapstructure:"timeout_seconds"`
	MemoryModel    string `mapstructure:"memory_model"`
	APIKey         string `mapstructure:"api_key"`
}

// TempMail 临时邮箱（make temp-mail-password 与 App 注册用）。
type TempMail struct {
	Enabled        bool   `mapstructure:"enabled"`
	BaseURL        string `mapstructure:"base_url"`
	FallbackDomain string `mapstructure:"fallback_domain"`
	TimeoutSeconds int    `mapstructure:"timeout_seconds"`
}

// PrivateMessage 私信持久化与保留天数。
type PrivateMessage struct {
	RetentionDaysDefault int `mapstructure:"retention_days_default"`
	RetentionDaysNormal  int `mapstructure:"retention_days_normal"`
	RetentionDaysVIP     int `mapstructure:"retention_days_vip"`
	BodyMaxRunes         int `mapstructure:"body_max_runes"`
	ImagePathsMax        int `mapstructure:"image_paths_max"`
}

// Feishu 企业自建应用机器人 + OAuth 登录。
type Feishu struct {
	Enabled             bool   `mapstructure:"enabled"`
	AppID               string `mapstructure:"app_id"`
	AppSecret           string `mapstructure:"app_secret"`
	ReceiveID           string `mapstructure:"receive_id"`
	ReceiveIDType       string `mapstructure:"receive_id_type"`
	RedirectURI         string `mapstructure:"redirect_uri"`
	OAuthScope          string `mapstructure:"oauth_scope"`
	AutoAddToDirectory  bool   `mapstructure:"auto_add_to_directory"`
	DefaultDepartmentID string `mapstructure:"default_department_id"`
	EnterpriseInviteURL string `mapstructure:"enterprise_invite_url"`
	EnterpriseNotice    string `mapstructure:"enterprise_notice"`
}

// Wechat 微信开放平台登录。三条 flow（app / website / mp）各自独立凭证，
// 历史扁平键（mobile_app_id、web_app_id、mp_app_id…）的回退见 derive.go。
type Wechat struct {
	Enabled     bool             `mapstructure:"enabled"`
	RedirectURI string           `mapstructure:"redirect_uri"`
	OAuthScope  string           `mapstructure:"oauth_scope"`
	App         WechatCredential `mapstructure:"app"`
	Website     WechatCredential `mapstructure:"website"`
	MP          WechatCredential `mapstructure:"mp"`
}

// WechatCredential 一条微信 flow 的 AppID / AppSecret。
type WechatCredential struct {
	AppID     string `mapstructure:"app_id"`
	AppSecret string `mapstructure:"app_secret"`
}

// Moe Intelligence Stack：调度器、模型选择、进程内装配开关。
type Moe struct {
	BotPostModel      string `mapstructure:"bot_post_model"`
	TopicAnalyzeModel string `mapstructure:"topic_analyze_model"`

	BotSchedulerEnabled       bool  `mapstructure:"bot_scheduler_enabled"`
	BotSchedulerTickSeconds   int64 `mapstructure:"bot_scheduler_tick_seconds"`
	DreamSchedulerEnabled     bool  `mapstructure:"dream_scheduler_enabled"`
	DreamSchedulerTickSeconds int64 `mapstructure:"dream_scheduler_tick_seconds"`
	BotSmartRetryMinutes      int   `mapstructure:"bot_smart_retry_minutes"`
	BotSmartMinIntervalHours  int   `mapstructure:"bot_smart_min_interval_hours"`

	// Life 引擎的 tick / flush 间隔（秒）。迁移前是 moewiring/api_life.go 里的编译期常量
	// livingWorldIntervalSeconds = 5*60，且两者共用同一个数 —— 调一次世界节奏就得改代码
	// 重新编译整个后端。缺省值放在 derive.go 的 LifeIntervals()，仍是 300 秒。
	LifeTickSeconds  int64 `mapstructure:"life_tick_seconds"`
	LifeFlushSeconds int64 `mapstructure:"life_flush_seconds"`

	// game 后台世界时钟的间隔（秒）。这个键**故意不在这里给缺省**：
	// gamebiz.defaultWorldTickInterval 已经是那个 45 秒的唯一副本，
	// derive.go 的 WorldTickInterval() 未配置时返回 0，由 StartWorldRunner 的
	// `interval <= 0` 守卫兜底 —— 再写一个 45 就会变成第三份副本。
	WorldTickSeconds int64 `mapstructure:"world_tick_seconds"`

	Production MoeProduction `mapstructure:"production"`

	// 装配开关。这些键的语义是「未设置时继承默认」而非「默认 false」，
	// 判定必须走 derive.go 的 DomainInProcess。
	APIInProcess      bool `mapstructure:"api_in_process"`
	SingleProcess     bool `mapstructure:"single_process"`
	LifeEngineEnabled bool `mapstructure:"life_engine_enabled"`
}

// MoeProduction 端口口径。ExternalHTTPPort 是字符串（"8888"），与 runtime.http_port 重复，
// 由 derive.go 的 HTTPPort() 作为回退读取。
//
// 这里曾还有 UnifiedEntry / InternalGRPCPort / PilotHTTPPort / PilotGRPCPort 四个字段，
// 全仓零读者已删：后三个连 config.yaml 里都不存在（单进程 HTTP-only，既无 gRPC 监听者也
// 无 pilot 进程，是 MoePilot 移除时的残留），unified_entry 在文件里但没人读 ——
// 四个都记在 Config 头部的死配置清单与变更记录 §18.2 的「50 个死键」里。
type MoeProduction struct {
	ExternalHTTPPort string `mapstructure:"external_http_port"`
}
