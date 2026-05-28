// Code scaffolded by goctl. Safe to edit.

package chat

import (
	"context"
	"net/http"

	"backend/api/internal/svc"
	chatbiz "backend/internal/biz/chat"
)

// WorldWs WebSocket 大世界同步（JSON，供 Godot WebSocketPeer 等连接）
func WorldWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		ctx = context.WithValue(ctx, "http.Request", r)
		ctx = context.WithValue(ctx, "http.ResponseWriter", &w)

		hr, _ := ctx.Value("http.Request").(*http.Request)
		hw, _ := ctx.Value("http.ResponseWriter").(*http.ResponseWriter)
		chatbiz.ServeWorldWS(*hw, hr)
	}
}
