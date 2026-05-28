package chat

import (
	"context"
	"net/http"

	chatbiz "backend/internal/biz/chat"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

type PresenceWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewPresenceWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *PresenceWsLogic {
	return &PresenceWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *PresenceWsLogic) PresenceWs() error {
	r, ok := l.ctx.Value("http.Request").(*http.Request)
	if !ok {
		return nil
	}
	w, ok := l.ctx.Value("http.ResponseWriter").(*http.ResponseWriter)
	if !ok {
		return nil
	}
	chatbiz.ServePresenceWS(*w, r)
	return nil
}

func (l *PresenceWsLogic) GetOnlineUsers() map[string]bool {
	return chatbiz.OnlineUserIDSet()
}
