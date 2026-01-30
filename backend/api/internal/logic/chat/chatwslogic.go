package chat

import (
	"context"

	"backend/api/internal/svc"
	"github.com/zeromicro/go-zero/core/logx"
)

type ChatWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// WebSocket聊天服务
func NewChatWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatWsLogic {
	return &ChatWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatWsLogic) ChatWs() error {
	// todo: add your logic here and delete this line

	return nil
}
