package apicomm

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// UserIDString 从 JWT 中间件注入的 context 读取当前用户 ID 字符串。
func UserIDString(ctx context.Context) (string, error) {
	var uidVal interface{}
	if v := ctx.Value("userId"); v != nil {
		uidVal = v
	} else if v := ctx.Value("user_id"); v != nil {
		uidVal = v
	}
	if uidVal == nil {
		return "", errors.New("未登录或 token 无效")
	}
	switch v := uidVal.(type) {
	case string:
		if v == "" {
			return "", errors.New("userId 为空")
		}
		return v, nil
	case json.Number:
		return v.String(), nil
	case float64:
		return fmt.Sprintf("%.0f", v), nil
	default:
		return "", errors.New("userId 类型无效")
	}
}

// UserIDUint 将 JWT context 中的 userId 转为 uint。
func UserIDUint(ctx context.Context) (uint, error) {
	s, err := UserIDString(ctx)
	if err != nil {
		return 0, err
	}
	n, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("userId 无效: %w", err)
	}
	return uint(n), nil
}

// ResolveActorUserID 提取当前请求的真实用户 ID（优先 context，次选 HTTP Bearer token）；
// 若均为无认证上下文（如内部直接调用 AppService / 单元测试未带 HTTP ctx），则回退至 claimedUserID。
func ResolveActorUserID(ctx context.Context, claimedUserID string) string {
	if s, err := UserIDString(ctx); err == nil && strings.TrimSpace(s) != "" {
		return strings.TrimSpace(s)
	}
	if req, ok := khttp.RequestFromServerContext(ctx); ok && req != nil {
		if s, err := bearerUserIDFromRequest(req); err == nil && s != "" {
			return s
		}
	}
	return strings.TrimSpace(claimedUserID)
}

// RequireSelfOrUnbound 校验当前已认证用户是否与 targetUserID 一致：
// - 若 context / HTTP request 中存在已认证用户 ID：targetUserID 为空则自动填入 actor；若非空且与 actor 不一致则返回 codes.PermissionDenied（防 IDOR 水平越权）。
// - 若为无 HTTP / 无 JWT 的内部进程内调用或裸单测，则保留 targetUserID。
func RequireSelfOrUnbound(ctx context.Context, targetUserID string) (string, error) {
	actor := ""
	if s, err := UserIDString(ctx); err == nil && strings.TrimSpace(s) != "" {
		actor = strings.TrimSpace(s)
	} else if req, ok := khttp.RequestFromServerContext(ctx); ok && req != nil {
		if s, err := bearerUserIDFromRequest(req); err == nil && s != "" {
			actor = s
		}
	}
	target := strings.TrimSpace(targetUserID)
	if actor != "" {
		if target != "" && target != actor {
			return "", status.Error(codes.PermissionDenied, "无权操作其他用户的数据")
		}
		return actor, nil
	}
	return target, nil
}

func bearerUserIDFromRequest(r *http.Request) (string, error) {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		auth = strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	if auth == "" {
		return "", errors.New("missing bearer token")
	}
	cl, err := utils.ParseToken(auth)
	if err != nil || cl.UserID == 0 {
		return "", errors.New("invalid bearer token")
	}
	return strconv.FormatUint(uint64(cl.UserID), 10), nil
}
