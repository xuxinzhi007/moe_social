package logic

import (
	"context"

	"backend/model"
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
	content := systemNotificationContent(in.GetTitle(), in.GetContent())
	if content == "" {
		return nil, errorx.InvalidArgument("通知内容不能为空")
	}

	var userIDs []uint
	if err := l.svcCtx.DB.Model(&model.User{}).Pluck("id", &userIDs).Error; err != nil {
		l.Errorf("[admin] broadcast list users: %v", err)
		return nil, errorx.Internal("广播通知失败")
	}

	created := int32(0)
	for _, uid := range userIDs {
		n := model.Notification{
			UserID:   uid,
			SenderID: 0,
			Type:     adminSystemNotificationType,
			Content:  content,
			IsRead:   false,
		}
		if err := l.svcCtx.DB.Omit("PostID").Create(&n).Error; err != nil {
			l.Errorf("[admin] broadcast create notification user=%d: %v", uid, err)
			continue
		}
		created++
	}
	return &super.AdminBroadcastNotificationResp{NotificationsCreated: created}, nil
}
