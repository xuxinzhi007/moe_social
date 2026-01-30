package chat

import (
	"context"

	"backend/api/internal/svc"
	"github.com/zeromicro/go-zero/core/logx"
)

type RemoteWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// WebSocket远程控制服务
func NewRemoteWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RemoteWsLogic {
	return &RemoteWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *RemoteWsLogic) RemoteWs() error {
	// todo: add your logic here and delete this line

	return nil
}
