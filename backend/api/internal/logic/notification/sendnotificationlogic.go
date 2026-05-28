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
	success := chat.SendWSNotification(&chat.SendNotificationReq{
		UserID: req.UserId,
		Type:   req.Type,
		Data:   req.Data,
	})
	if !success {
		return &types.BaseResp{
			Code:    500,
			Message: "发送失败",
			Success: false,
		}, nil
	}
	return &types.BaseResp{
		Code:    200,
		Message: "发送成功",
		Success: true,
	}, nil
}
