package chat

import (
	"context"
	"net/http"

	chatbiz "backend/internal/biz/chat"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

type ChatWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewChatWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatWsLogic {
	return &ChatWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatWsLogic) ChatWs() error {
	r, ok := l.ctx.Value("http.Request").(*http.Request)
	if !ok {
		return nil
	}
	w, ok := l.ctx.Value("http.ResponseWriter").(*http.ResponseWriter)
	if !ok {
		return nil
	}
	deps := chatWSDeps(l.svcCtx)
	chatbiz.ServeChatWS(*w, r, l.ctx, deps)
	return nil
}

func chatWSDeps(svcCtx *svc.ServiceContext) chatbiz.ChatWSDeps {
	deps := chatbiz.ChatWSDeps{
		PM:       svcCtx.ChatGW,
		Delivery: chatbiz.DeliveryDeps{UserReader: svcCtx.UserGW, NotifyRPC: svcCtx.UserGW},
	}
	if svcCtx != nil && svcCtx.UserApp != nil {
		deps.Delivery.DB = svcCtx.UserApp.DB()
	}
	return deps
}
