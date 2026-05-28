package chat

import (
	"context"
	"net/http"

	chatbiz "backend/internal/biz/chat"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

type WorldWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewWorldWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WorldWsLogic {
	return &WorldWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *WorldWsLogic) WorldWs() error {
	r, ok := l.ctx.Value("http.Request").(*http.Request)
	if !ok {
		return nil
	}
	w, ok := l.ctx.Value("http.ResponseWriter").(*http.ResponseWriter)
	if !ok {
		return nil
	}
	chatbiz.ServeWorldWS(*w, r)
	return nil
}
