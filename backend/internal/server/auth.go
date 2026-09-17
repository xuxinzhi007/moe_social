package server

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"backend/utils"
)

// publicReadPrefixes 无需认证即可读取的路径前缀（仅对安全方法 GET/HEAD/OPTIONS 生效）。
//
// 分成读/写两张表是刻意的。早先只有一张不分方法的 publicPaths，前缀命中就一律放行，
// 于是任何"前缀恰好被覆盖"的写路由都变成了免认证接口 —— 实测两条：
//   - POST /api/llm/models/delete 与 /api/llm/models/download 被 /api/llm/models 前缀放行，
//     一路到底没有任何身份校验（Platform 适配层只判 deps.LLMApp 是否为 nil），
//     仅仅因为 llmbiz 那两个函数还是 501 未实现的桩，才没真把推理端的模型删掉。
//     这两条路由已在 #42 死接口清理中连同 proto 一起删除（客户端零调用方），
//     但 /api/llm/models 这条读前缀还得留着 —— 见下面表内注释；
//   - DELETE /api/images/{filename} 被 /api/images/ 放行，穿过过滤器后
//     只靠 media 适配层自己再查一次 claims 才被挡住 —— 防线在错的那一层。
//     这条今天仍然是活路由，是分表唯一还在承重的实测证据。
var publicReadPrefixes = []string{
	// 换取 token 之前的引导流程（读部分）
	"/api/auth/feishu/public-config",
	"/api/auth/feishu/authorize-url",
	"/api/auth/wechat/authorize-url",

	// OAuth 回调：浏览器重定向打过来的 GET，不可能带 Authorization。
	// 两个回调在 transport/oauth.go 里完全对称，曾经只有 wechat 在表里，
	// 飞书回调被过滤器拦成 401（实测），整条飞书登录走不完。
	"/api/auth/feishu/callback",
	"/api/auth/wechat/callback",

	// 公开图片：帖子与头像里的 /api/images/{key} 任何人都要能看。
	// 前缀带斜杠，所以 GET /api/images（列表）不在放行范围内，仍需登录。
	"/api/images/",

	// 文档与运维
	"/health",
	"/swagger",

	// App 配置 / 公告 / LLM 目录（无需登录即可拉取）
	"/api/public/client-config",
	"/api/public/app-release",
	"/api/announcements",
	"/api/llm/config",
	// 这条同时覆盖 /api/llm/models/raw：终端模式下 Flutter 的 modelsUri() 打的就是它，
	// 而 ai_chat_gateway_service.dart:146 只 mergeTunnelHeaders、不带 bearer。
	// 别把它改成精确匹配，否则终端模式的模型列表会静默 401。
	// 写方法不在这里放行，所以 /api/llm/models/delete 与 /download 已恢复需登录。
	"/api/llm/models",
}

// publicWritePrefixes 无需认证即可写入的路径前缀。
// 只放"换取 token 之前必须能打"的引导流程；任何登录后的写操作都不该出现在这里。
var publicWritePrefixes = []string{
	// 登录 / 注册引导
	"/api/user/login",
	"/api/user/register",
	"/api/user/check-email",
	"/api/user/temp-mail/",
	"/api/auth/feishu/login",
	"/api/auth/wechat/login",

	// 找回密码。下面三条路由后端尚未实现（实测 404，Flutter 的 verify_code_page.dart:49,71
	// 已经在打），留在这里是为了将来补上路由时不必再回来动鉴权。
	//
	// 已知越权风险，本轮按用户决定暂不处理：/api/user/reset-password 不校验任何验证码，
	// ResetPasswordReq 里连 code 字段都没有，仅凭 email 就能改掉该账号密码。
	// 这里保持原样放行，不要顺手改它的语义。
	"/api/user/send-reset-code",
	"/api/user/verify-reset-code",
	"/api/user/reset-password",

	// 落地页反馈（无需登录）
	"/api/landing/feedback",
}

// 已从白名单删除的死条目（全仓零路由，删掉不影响任何调用方）：
//   /api/admin/            —— jwtAuthFilter 的 admin 分支在 requiresAuth 之前就把它仲裁掉了，这条永远轮不到
//   /api/media/            —— 上传实际注册在 /api/upload（media_http.go:19）
//   /doc /api/doc /api/swagger —— 文档路由只有 /swagger*（http_docs.go:15-21）
//   /api/platform/app-cfg /api/platform/config /api/platform/announcements —— 无此前缀的任何路由
//   /api/llm/models-raw /api/llm/show-raw —— 真实路径是 /raw 不是 -raw（platform_llm_raw.go:28-29）

// jwtAuthFilter 解析 Authorization: Bearer <token> 并将 userId 注入到请求 context 中。
// 写入 "userId" 和 "user_id" 两个 key，兼容 apicomm.UserIDString 和 llm platform_chat_memory。
//
// /api/admin/ 由下面第一个分支单独仲裁，要求管理员 token（/api/admin/login 除外），
// 永远走不到 requiresAuth —— 所以白名单里不需要、也不该再留 /api/admin/ 这一条。
// 其余路径按方法查 publicReadPrefixes / publicWritePrefixes。
func jwtAuthFilter(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path

		if strings.HasPrefix(path, "/api/admin/") {
			if path == "/api/admin/login" {
				next.ServeHTTP(w, r)
				return
			}
			token := extractBearerToken(r)
			if token == "" {
				writeUnauthorized(w, "请先登录管理后台")
				return
			}
			claims, err := utils.ParseAdminToken(token)
			if err != nil {
				writeUnauthorized(w, "登录已过期，请重新登录")
				return
			}
			ctx := r.Context()
			ctx = context.WithValue(ctx, "admin_id", claims.AdminID)
			ctx = context.WithValue(ctx, "admin_username", claims.Username)
			ctx = context.WithValue(ctx, "admin_role", claims.Role)
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}

		if !requiresAuth(r) {
			next.ServeHTTP(w, r)
			return
		}

		token := extractBearerToken(r)
		if token == "" {
			writeUnauthorized(w, "缺少认证信息，请先登录")
			return
		}

		claims, err := utils.ParseToken(token)
		if err != nil {
			writeUnauthorized(w, "登录已过期，请重新登录")
			return
		}

		if claims.UserID == 0 {
			writeUnauthorized(w, "无效的用户身份")
			return
		}

		uidStr := strconv.FormatUint(uint64(claims.UserID), 10)
		ctx := r.Context()

		ctx = context.WithValue(ctx, "userId", uidStr)
		ctx = context.WithValue(ctx, "user_id", uidStr)
		ctx = context.WithValue(ctx, "jwt_username", claims.Username)

		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// requiresAuth 判断请求是否需要认证。
//
// 安全方法（GET/HEAD/OPTIONS）查 publicReadPrefixes，写方法查 publicWritePrefixes，
// 两张表都不命中就要认证。
//
// 早先这里只有一张不分方法的表，前缀命中就直接 return false；后面那段区分写方法与 GET 的
// 分支两个 return 都是 true，是彻底的死代码，还和注释里「所有写操作强制认证」正好相反。
// OPTIONS 实际到不了这里（corsFilter 在它之前就把预检 204 掉了），列进安全方法只为语义完整。
func requiresAuth(r *http.Request) bool {
	path := r.URL.Path
	prefixes := publicWritePrefixes
	if isSafeMethod(r.Method) {
		prefixes = publicReadPrefixes
	}
	for _, prefix := range prefixes {
		if strings.HasPrefix(path, prefix) {
			return false
		}
	}
	return true
}

func isSafeMethod(method string) bool {
	switch method {
	case http.MethodGet, http.MethodHead, http.MethodOptions:
		return true
	default:
		return false
	}
}

// extractBearerToken 从 Authorization header 提取 Bearer token。
// Fallback: 从 query 参数读取（WebSocket 升级请求可能无法设置自定义 header）。
func extractBearerToken(r *http.Request) string {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	// Fallback: 从 query 参数读取 token（WebSocket 场景）
	if token := r.URL.Query().Get("token"); token != "" {
		return token
	}
	return ""
}

func writeUnauthorized(w http.ResponseWriter, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"code":    401,
		"success": false,
		"message": message,
	})
}

// MustActorUserID 从 context 中提取当前登录用户 ID，失败直接 panic。
// 适用于 handler 中已知必须登录的场景。
func MustActorUserID(ctx context.Context) uint {
	uidStr := ""
	if v := ctx.Value("userId"); v != nil {
		uidStr = toString(v)
	} else if v := ctx.Value("user_id"); v != nil {
		uidStr = toString(v)
	}
	if uidStr == "" {
		panic("未登录或认证已过期")
	}
	n, err := strconv.ParseUint(uidStr, 10, 64)
	if err != nil || n == 0 {
		panic("无效的用户身份")
	}
	return uint(n)
}

func toString(v interface{}) string {
	switch s := v.(type) {
	case string:
		return s
	case json.Number:
		return s.String()
	case float64:
		return strconv.FormatFloat(s, 'f', -1, 64)
	default:
		return ""
	}
}
