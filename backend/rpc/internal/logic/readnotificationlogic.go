package logic

import (
	"context"
	"strconv"

	"backend/model"
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
	return &ReadNotificationLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ReadNotificationLogic) ReadNotification(in *super.ReadNotificationReq) (*super.ReadNotificationResp, error) {
	id, err := strconv.ParseUint(in.Id, 10, 32)
	if err != nil {
		return nil, err
	}
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, err
	}

	// 确保只能标记自己的通知
	result := l.svcCtx.DB.Model(&model.Notification{}).
		Where("id = ? AND user_id = ?", id, userID).
		Update("is_read", true)

	if result.Error != nil {
		l.Error("标记通知已读失败:", result.Error)
		return nil, result.Error
	}

	return &super.ReadNotificationResp{}, nil
}
