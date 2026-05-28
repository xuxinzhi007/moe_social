package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminSendNotificationLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminSendNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminSendNotificationLogic {
	return &AdminSendNotificationLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminSendNotificationLogic) AdminSendNotification(in *super.AdminSendNotificationReq) (*super.AdminSendNotificationResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).SendNotification(l.ctx, in)
	if err != nil {
		return nil, mapAdminNotifyErr(err)
	}
	return resp, nil
}
