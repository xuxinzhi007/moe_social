package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetNotificationsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetNotificationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetNotificationsLogic {
	return &GetNotificationsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 通知相关服务
func (l *GetNotificationsLogic) GetNotifications(in *super.GetNotificationsReq) (*super.GetNotificationsResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, err
	}

	page := int(in.Page)
	if page < 1 {
		page = 1
	}
	pageSize := int(in.PageSize)
	if pageSize < 1 {
		pageSize = 10
	}
	offset := (page - 1) * pageSize

	var notifications []model.Notification
	var total int64

	// 构建查询
	db := l.svcCtx.DB.Model(&model.Notification{}).Where("user_id = ?", userID)

	// 获取总数
	if err := db.Count(&total).Error; err != nil {
		l.Error("查询通知总数失败:", err)
		return nil, err
	}

	// 获取列表
	if err := db.Order("created_at desc").
		Offset(offset).Limit(pageSize).
		Preload("Sender").
		Find(&notifications).Error; err != nil {
		l.Error("查询通知列表失败:", err)
		return nil, err
	}

	// 转换格式
	var rpcNotifications []*super.Notification
	for _, n := range notifications {
		senderName := "未知用户"
		if n.Sender.Username != "" {
			senderName = n.Sender.Username
		} else if n.Sender.Email != "" {
			senderName = n.Sender.Email
		}

		rpcNotifications = append(rpcNotifications, &super.Notification{
			Id:           strconv.FormatUint(uint64(n.ID), 10),
			UserId:       strconv.FormatUint(uint64(n.UserID), 10),
			SenderId:     strconv.FormatUint(uint64(n.SenderID), 10),
			SenderName:   senderName,
			SenderAvatar: n.Sender.Avatar,
			Type:         int32(n.Type),
			PostId:       strconv.FormatUint(uint64(n.PostID), 10),
			Content:      n.Content,
			IsRead:       n.IsRead,
			CreatedAt:    n.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	return &super.GetNotificationsResp{
		Notifications: rpcNotifications,
		Total:         int32(total),
	}, nil
}
