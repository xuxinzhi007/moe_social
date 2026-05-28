package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBroadcastNotificationLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBroadcastNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBroadcastNotificationLogic {
	return &AdminBroadcastNotificationLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminBroadcastNotificationLogic) AdminBroadcastNotification(in *super.AdminBroadcastNotificationReq) (*super.AdminBroadcastNotificationResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).BroadcastNotification(l.ctx, in)
	if err != nil {
		return nil, mapAdminNotifyErr(err)
	}
	return resp, nil
}
