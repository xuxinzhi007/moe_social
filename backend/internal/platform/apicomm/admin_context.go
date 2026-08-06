package apicomm

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"strings"

	"backend/internal/legacy/types"
	"backend/utils"
)

type adminActorContextKey struct{}

// AdminActor 当前 HTTP 请求的管理员身份（由 handler 注入 context）。
type AdminActor struct {
	AdminID   uint
	AdminName string
	IP        string
}

// WithAdminActor 将管理员身份写入 context。
func WithAdminActor(ctx context.Context, claims *utils.AdminClaims, ip string) context.Context {
	if claims == nil {
		return ctx
	}
	return context.WithValue(ctx, adminActorContextKey{}, AdminActor{
		AdminID:   claims.AdminID,
		AdminName: claims.Username,
		IP:        strings.TrimSpace(ip),
	})
}

// AdminActorFromContext 读取管理员身份。
func AdminActorFromContext(ctx context.Context) (AdminActor, bool) {
	v := ctx.Value(adminActorContextKey{})
	if v == nil {
		return AdminActor{}, false
	}
	actor, ok := v.(AdminActor)
	return actor, ok && actor.AdminID > 0
}

// ClientIP 从 HTTP 请求解析客户端 IP。
func ClientIP(r *http.Request) string {
	if r == nil {
		return ""
	}
	if xff := strings.TrimSpace(r.Header.Get("X-Forwarded-For")); xff != "" {
		parts := strings.Split(xff, ",")
		if ip := strings.TrimSpace(parts[0]); ip != "" {
			return ip
		}
	}
	if xrip := strings.TrimSpace(r.Header.Get("X-Real-IP")); xrip != "" {
		return xrip
	}
	host, _, err := net.SplitHostPort(strings.TrimSpace(r.RemoteAddr))
	if err == nil && host != "" {
		return host
	}
	return strings.TrimSpace(r.RemoteAddr)
}

// WriteAdminUnauthorized 返回统一的管理员未授权 JSON。
func WriteAdminUnauthorized(w http.ResponseWriter, r *http.Request, br *types.BaseResp) {
	if br == nil {
		br = &types.BaseResp{Code: -1, Message: "请先登录管理后台", Success: false}
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"success": br.Success,
		"code":    br.Code,
		"message": br.Message,
	})
}

// PrepareAdminContext 校验 X-Admin-Token 并将管理员身份写入 context。
func PrepareAdminContext(w http.ResponseWriter, r *http.Request) (context.Context, bool) {
	claims, br := RequireAdminToken(r)
	if br != nil {
		WriteAdminUnauthorized(w, r, br)
		return r.Context(), false
	}
	return WithAdminActor(r.Context(), claims, ClientIP(r)), true
}
