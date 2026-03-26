// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package chat

import (
	"context"
	"net/http"

	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
)

// WebSocket在线状态服务
func PresenceWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// 创建一个新的上下文，包含 HTTP 请求和响应
		ctx := r.Context()
		ctx = context.WithValue(ctx, "http.Request", r)
		ctx = context.WithValue(ctx, "http.ResponseWriter", &w)

		l := chat.NewPresenceWsLogic(ctx, svcCtx)
		_ = l.PresenceWs()
		// WebSocket 连接已经升级，不需要返回响应
	}
}
