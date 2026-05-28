package logic

import (
	"context"

	notifybiz "backend/internal/biz/notify"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateNotificationLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateNotificationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateNotificationLogic {
	return &CreateNotificationLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreateNotificationLogic) CreateNotification(in *super.CreateNotificationReq) (*super.CreateNotificationResp, error) {
	if err := notifybiz.CreateInbox(l.ctx, l.svcCtx.DB, in); err != nil {
		l.Error("创建通知失败:", err)
		return nil, err
	}
	return &super.CreateNotificationResp{}, nil
}
