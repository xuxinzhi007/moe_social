package logic

import (
	"context"
	"strconv"

	"backend/model"
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
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, err
	}

	senderID, err := strconv.ParseUint(in.SenderId, 10, 32)
	if err != nil {
		return nil, err
	}

	var postID uint64
	if in.PostId != "" {
		postID, err = strconv.ParseUint(in.PostId, 10, 32)
		if err != nil {
			return nil, err
		}
	}

	content := in.Content
	if len(content) > 200 {
		content = content[:200]
	}

	notification := model.Notification{
		UserID:   uint(userID),
		SenderID: uint(senderID),
		Type:     int(in.Type),
		PostID:   uint(postID),
		Content:  content,
		IsRead:   false,
	}

	if err := l.svcCtx.DB.Create(&notification).Error; err != nil {
		l.Error("创建通知失败:", err)
		return nil, err
	}

	return &super.CreateNotificationResp{
		Notification: &super.Notification{
			Id:        strconv.FormatUint(uint64(notification.ID), 10),
			UserId:    strconv.FormatUint(uint64(notification.UserID), 10),
			SenderId:  strconv.FormatUint(uint64(notification.SenderID), 10),
			Type:      int32(notification.Type),
			PostId:    strconv.FormatUint(uint64(notification.PostID), 10),
			Content:   notification.Content,
			IsRead:    notification.IsRead,
			CreatedAt: notification.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil

}
