package notification

import (
	"context"

	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type BroadcastNotificationLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewBroadcastNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *BroadcastNotificationLogic {
	return &BroadcastNotificationLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *BroadcastNotificationLogic) BroadcastNotification(req *types.BroadcastNotificationReq) (resp *types.BaseResp, err error) {
	// 创建 RemoteWsLogic 实例来发送通知
	remoteWsLogic := chat.NewRemoteWsLogic(l.ctx, l.svcCtx)

	// 构建广播通知请求
	notificationReq := &chat.BroadcastNotificationReq{
		Type: req.Type,
		Data: req.Data,
	}

	// 发送广播通知
	_ = remoteWsLogic.BroadcastNotification(notificationReq)

	return &types.BaseResp{
		Code:    200,
		Message: "广播成功",
		Success: true,
	}, nil
}