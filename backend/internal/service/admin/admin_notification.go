package adminapp

import (
	"context"
	chatbiz "backend/internal/biz/chat"
	notifybiz "backend/internal/biz/notify"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

// BroadcastNotification 广播系统通知。
func (s *AppService) BroadcastNotification(ctx context.Context, in *adminv1.AdminBroadcastNotificationReq) (*adminv1.AdminBroadcastNotificationResp, error) {
	created, err := notifybiz.Broadcast(ctx, s.notify, in.GetTitle(), in.GetContent())
	if err != nil {
		return nil, err
	}
	wsSent := int32(chatbiz.BroadcastPush(chatbiz.BroadcastPushInput{
		Type: "system_notification",
		Data: map[string]interface{}{
			"title":   in.GetTitle(),
			"content": in.GetContent(),
		},
	}))
	return &adminv1.AdminBroadcastNotificationResp{
		NotificationsCreated: created,
		WsSent:               wsSent,
	}, nil
}

// SendNotification 向单用户发送系统通知。
func (s *AppService) SendNotification(ctx context.Context, in *adminv1.AdminSendNotificationReq) (*adminv1.AdminSendNotificationResp, error) {
	id, err := notifybiz.SendToUser(ctx, s.notify, in.GetUserId(), in.GetTitle(), in.GetContent())
	if err != nil {
		return nil, err
	}
	return adminbiz.SendNotificationV1(id), nil
}
