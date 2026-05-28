// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package chat

import (
	"context"
	"net/http"

	"backend/api/internal/svc"
	chatbiz "backend/internal/biz/chat"
)

// WebSocket在线状态服务
func PresenceWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		ctx = context.WithValue(ctx, "http.Request", r)
		ctx = context.WithValue(ctx, "http.ResponseWriter", &w)

		hr, _ := ctx.Value("http.Request").(*http.Request)
		hw, _ := ctx.Value("http.ResponseWriter").(*http.ResponseWriter)
		chatbiz.ServePresenceWS(*hw, hr)
	}
}
