// Code scaffolded by goctl. Safe to edit.

package chat

import (
	"context"
	"net/http"

	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
)

// WorldWs WebSocket 大世界同步（JSON，供 Godot WebSocketPeer 等连接）
func WorldWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		ctx = context.WithValue(ctx, "http.Request", r)
		ctx = context.WithValue(ctx, "http.ResponseWriter", &w)

		l := chat.NewWorldWsLogic(ctx, svcCtx)
		_ = l.WorldWs()
	}
}
