package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ReadAllNotificationsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewReadAllNotificationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ReadAllNotificationsLogic {
	return &ReadAllNotificationsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ReadAllNotificationsLogic) ReadAllNotifications(in *super.ReadAllNotificationsReq) (*super.ReadAllNotificationsResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, err
	}

	if err := l.svcCtx.DB.Model(&model.Notification{}).
		Where("user_id = ? AND is_read = ?", userID, false).
		Update("is_read", true).Error; err != nil {
		l.Error("标记所有通知已读失败:", err)
		return nil, err
	}

	return &super.ReadAllNotificationsResp{}, nil
}
