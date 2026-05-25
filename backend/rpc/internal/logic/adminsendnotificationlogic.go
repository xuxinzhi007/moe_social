package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
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
	userID, err := strconv.ParseUint(strings.TrimSpace(in.GetUserId()), 10, 64)
	if err != nil || userID == 0 {
		return nil, errorx.InvalidArgument("用户 ID 无效")
	}
	content := systemNotificationContent(in.GetTitle(), in.GetContent())
	if content == "" {
		return nil, errorx.InvalidArgument("通知内容不能为空")
	}

	var user model.User
	if err := l.svcCtx.DB.First(&user, userID).Error; err != nil {
		return nil, errorx.NotFound("用户不存在")
	}

	n := model.Notification{
		UserID:   uint(userID),
		SenderID: 0,
		Type:     adminSystemNotificationType,
		Content:  content,
		IsRead:   false,
	}
	if err := l.svcCtx.DB.Omit("PostID").Create(&n).Error; err != nil {
		l.Errorf("[admin] send notification: %v", err)
		return nil, errorx.Internal("发送通知失败")
	}
	return &super.AdminSendNotificationResp{NotificationId: strconv.FormatUint(uint64(n.ID), 10)}, nil
}
