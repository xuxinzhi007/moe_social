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
	_ = chat.BroadcastWSNotification(&chat.BroadcastNotificationReq{
		Type: req.Type,
		Data: req.Data,
	})

	return &types.BaseResp{
		Code:    200,
		Message: "广播成功",
		Success: true,
	}, nil
}