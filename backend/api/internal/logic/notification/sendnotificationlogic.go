package notification

import (
	"context"

	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendNotificationLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSendNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendNotificationLogic {
	return &SendNotificationLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SendNotificationLogic) SendNotification(req *types.SendNotificationReq) (resp *types.BaseResp, err error) {
	// 创建 RemoteWsLogic 实例来发送通知
	remoteWsLogic := chat.NewRemoteWsLogic(l.ctx, l.svcCtx)

	// 构建通知请求
	notificationReq := &chat.SendNotificationReq{
		UserID: req.UserId,
		Type:   req.Type,
		Data:   req.Data,
	}

	// 发送通知
	success := remoteWsLogic.SendNotification(notificationReq)

	if success {
		return &types.BaseResp{
			Code:    200,
			Message: "发送成功",
			Success: true,
		}, nil
	} else {
		return &types.BaseResp{
			Code:    404,
			Message: "用户不在线",
			Success: false,
		}, nil
	}
}