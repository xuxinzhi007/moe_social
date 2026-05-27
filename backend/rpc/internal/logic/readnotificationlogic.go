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

type ReadNotificationLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewReadNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ReadNotificationLogic {
	return &ReadNotificationLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ReadNotificationLogic) ReadNotification(in *super.ReadNotificationReq) (*super.ReadNotificationResp, error) {
	if err := notifybiz.MarkRead(l.ctx, l.svcCtx.DB, in.GetUserId(), in.GetId()); err != nil {
		switch {
		case errors.Is(err, notifybiz.ErrInvalidUserID), errors.Is(err, notifybiz.ErrInvalidNotificationID):
			return nil, errorx.InvalidArgument("参数无效")
		default:
			l.Error("标记通知已读失败:", err)
			return nil, errorx.Internal("标记通知已读失败")
		}
	}
	return &super.ReadNotificationResp{}, nil
}
