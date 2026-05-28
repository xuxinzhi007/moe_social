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

type GetNotificationsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetNotificationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetNotificationsLogic {
	return &GetNotificationsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetNotificationsLogic) GetNotifications(in *moe.GetNotificationsReq) (*moe.GetNotificationsResp, error) {
	items, total, err := notifybiz.ListInbox(l.ctx, l.svcCtx.NotifyStore(), in.GetUserId(), notifybiz.InboxPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		if errors.Is(err, notifybiz.ErrInvalidUserID) {
			return nil, errorx.InvalidArgument("用户 ID 无效")
		}
		l.Error("查询通知列表失败:", err)
		return nil, errorx.Internal("查询通知列表失败")
	}
	return &moe.GetNotificationsResp{Notifications: items, Total: total}, nil
}
