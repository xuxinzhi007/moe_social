package server

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"backend/utils"
)

// publicPaths 无需认证的路径前缀（前缀匹配）。
var publicPaths = []string{
	// 登录 / 注册 / OAuth 引导（换取 token 之前）
	"/api/user/login",
	"/api/user/register",
	"/api/user/check-email",
	"/api/user/temp-mail/",
	"/api/user/send-reset-code",
	"/api/user/verify-reset-code",
	"/api/user/reset-password",
	"/api/auth/feishu/public-config",
	"/api/auth/feishu/authorize-url",
	"/api/auth/feishu/login",
	"/api/auth/wechat/authorize-url",
	"/api/auth/wechat/login",
	"/api/auth/wechat/callback",

	// 管理后台（使用 X-Admin-Token，由 adminContext 单独认证）
	"/api/admin/",

	// 公开媒体资源（GET）
	"/api/images/",
	"/api/media/",

	// 文档与运维
	"/health",
	"/swagger",
	"/doc",
	"/api/doc",
	"/api/swagger",

	// App 配置 / 公告 / LLM 目录（无需登录即可拉取）
	"/api/platform/app-cfg",
	"/api/platform/config",
	"/api/platform/announcements",
	"/api/public/client-config",
	"/api/public/app-release",
	"/api/announcements",
	"/api/llm/config",
	"/api/llm/models",
	"/api/llm/models-raw",
	"/api/llm/show-raw",

	// 落地页反馈（无需登录）
	"/api/landing/feedback",
}

// jwtAuthFilter 解析 Authorization: Bearer <token> 并将 userId 注入到请求 context 中。
// 写入 "userId" 和 "user_id" 两个 key，兼容 apicomm.UserIDString 和 llm platform_chat_memory。
// 对 publicPaths 中的 GET 路径跳过认证；所有写操作（POST/PUT/PATCH/DELETE）强制认证。
func jwtAuthFilter(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path

		if strings.HasPrefix(path, "/api/admin/") {
			if path == "/api/admin/login" || path == "/api/admin/bootstrap/account" {
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
func requiresAuth(r *http.Request) bool {
	path := r.URL.Path
	// 检查前缀白名单（所有方法都跳过）
	for _, prefix := range publicPaths {
		if strings.HasPrefix(path, prefix) {
			return false
		}
	}
	// 写操作强制认证
	method := r.Method
	if method == http.MethodPost || method == http.MethodPut ||
		method == http.MethodPatch || method == http.MethodDelete {
		return true
	}
	// GET：不在白名单中的需要认证
	return true
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
