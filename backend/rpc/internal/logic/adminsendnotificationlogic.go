package logic

import (
	"context"
	"errors"
	"strconv"

	notifybiz "backend/internal/biz/notify"
	"backend/rpc/internal/errorx"
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
	id, err := notifybiz.SendToUser(l.ctx, l.svcCtx.DB, in.GetUserId(), in.GetTitle(), in.GetContent())
	if err != nil {
		switch {
		case errors.Is(err, notifybiz.ErrInvalidUserID):
			return nil, errorx.InvalidArgument("用户 ID 无效")
		case errors.Is(err, notifybiz.ErrEmptyContent):
			return nil, errorx.InvalidArgument("通知内容不能为空")
		case errors.Is(err, notifybiz.ErrUserNotFound):
			return nil, errorx.NotFound("用户不存在")
		default:
			l.Errorf("[admin] send notification: %v", err)
			return nil, errorx.Internal("发送通知失败")
		}
	}
	return &super.AdminSendNotificationResp{NotificationId: strconv.FormatUint(uint64(id), 10)}, nil
}
