package logic

import (
	"context"
	"errors"

	notifybiz "backend/internal/biz/notify"
	"backend/rpc/internal/errorx"
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
	created, err := notifybiz.Broadcast(l.ctx, l.svcCtx.DB, in.GetTitle(), in.GetContent())
	if err != nil {
		switch {
		case errors.Is(err, notifybiz.ErrEmptyContent):
			return nil, errorx.InvalidArgument("通知内容不能为空")
		default:
			l.Errorf("[admin] broadcast notification: %v", err)
			return nil, errorx.Internal("广播通知失败")
		}
	}
	return &super.AdminBroadcastNotificationResp{NotificationsCreated: created}, nil
}
