// Package userapp 通知收件箱。
package userapp

import (
	"context"
	notifybiz "backend/internal/biz/notify"
	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
)

// Package userapp 通知收件箱。

// GetNotifications 通知列表。
func (s *AppService) GetNotifications(ctx context.Context, in *userv1.GetNotificationsReq) (*userv1.GetNotificationsResp, error) {
	items, total, err := notifybiz.ListInbox(ctx, s.notify, in.GetUserId(), notifybiz.InboxPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return userbiz.NotificationsRespV1(userbiz.NotificationsFromNotifyV1(items), total), nil
}

// GetUnreadCount 未读数。
func (s *AppService) GetUnreadCount(ctx context.Context, in *userv1.GetUnreadCountReq) (*userv1.GetUnreadCountResp, error) {
	count, err := notifybiz.UnreadCount(ctx, s.notify, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &userv1.GetUnreadCountResp{Count: count}, nil
}

// ReadNotification 标记已读。
func (s *AppService) ReadNotification(ctx context.Context, in *userv1.ReadNotificationReq) (*userv1.ReadNotificationResp, error) {
	if err := notifybiz.MarkRead(ctx, s.notify, in.GetUserId(), in.GetId()); err != nil {
		return nil, err
	}
	return &userv1.ReadNotificationResp{}, nil
}

// ReadAllNotifications 全部已读。
func (s *AppService) ReadAllNotifications(ctx context.Context, in *userv1.ReadAllNotificationsReq) (*userv1.ReadAllNotificationsResp, error) {
	if err := notifybiz.MarkAllRead(ctx, s.notify, in.GetUserId()); err != nil {
		return nil, err
	}
	return &userv1.ReadAllNotificationsResp{}, nil
}
