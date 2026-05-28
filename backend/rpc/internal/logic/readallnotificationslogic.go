package logic

import (
	"context"
	"errors"

	notifybiz "backend/internal/biz/notify"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type ReadAllNotificationsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewReadAllNotificationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ReadAllNotificationsLogic {
	return &ReadAllNotificationsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ReadAllNotificationsLogic) ReadAllNotifications(in *moe.ReadAllNotificationsReq) (*moe.ReadAllNotificationsResp, error) {
	if err := notifybiz.MarkAllRead(l.ctx, l.svcCtx.DB, in.GetUserId()); err != nil {
		if errors.Is(err, notifybiz.ErrInvalidUserID) {
			return nil, errorx.InvalidArgument("用户 ID 无效")
		}
		l.Error("标记所有通知已读失败:", err)
		return nil, errorx.Internal("标记所有通知已读失败")
	}
	return &moe.ReadAllNotificationsResp{}, nil
}
