package notification

import (
	"context"

	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendBatchNotificationLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSendBatchNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendBatchNotificationLogic {
	return &SendBatchNotificationLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SendBatchNotificationLogic) SendBatchNotification(req *types.SendBatchNotificationReq) (resp *types.BaseResp, err error) {
	// 创建 RemoteWsLogic 实例来发送通知
	remoteWsLogic := chat.NewRemoteWsLogic(l.ctx, l.svcCtx)

	// 构建批量通知请求
	notificationReq := &chat.SendBatchNotificationReq{
		UserIDs: req.UserIDs,
		Type:    req.Type,
		Data:    req.Data,
	}

	// 发送批量通知
	_ = remoteWsLogic.SendBatchNotification(notificationReq)

	return &types.BaseResp{
		Code:    200,
		Message: "发送成功",
		Success: true,
	}, nil
}