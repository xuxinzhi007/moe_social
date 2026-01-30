package chat

import (
	"context"

	"backend/api/internal/svc"
	"github.com/zeromicro/go-zero/core/logx"
)

type PresenceWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// WebSocket在线状态服务
func NewPresenceWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *PresenceWsLogic {
	return &PresenceWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *PresenceWsLogic) PresenceWs() error {
	// todo: add your logic here and delete this line

	return nil
}
