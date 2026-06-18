package notifyapp

import (
	"context"
	notifyv1 "backend/api/notify/v1"
	notifybiz "backend/internal/biz/notify"
)

// GetNotifications 通知列表。
func (s *AppService) GetNotifications(ctx context.Context, in *notifyv1.GetNotificationsRequest) (*notifyv1.GetNotificationsReply, error) {
	items, total, err := notifybiz.ListInbox(ctx, s.store, in.GetUserId(), notifybiz.InboxPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return &notifyv1.GetNotificationsReply{Notifications: items, Total: total}, nil
}

// GetUnreadCount 未读数。
func (s *AppService) GetUnreadCount(ctx context.Context, in *notifyv1.GetUnreadCountRequest) (*notifyv1.GetUnreadCountReply, error) {
	count, err := notifybiz.UnreadCount(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &notifyv1.GetUnreadCountReply{Count: count}, nil
}

// ReadNotification 标记已读。
func (s *AppService) ReadNotification(ctx context.Context, in *notifyv1.ReadNotificationRequest) (*notifyv1.ReadNotificationReply, error) {
	if err := notifybiz.MarkRead(ctx, s.store, in.GetUserId(), in.GetId()); err != nil {
		return nil, err
	}
	return &notifyv1.ReadNotificationReply{}, nil
}

// ReadAllNotifications 全部已读。
func (s *AppService) ReadAllNotifications(ctx context.Context, in *notifyv1.ReadAllNotificationsRequest) (*notifyv1.ReadAllNotificationsReply, error) {
	if err := notifybiz.MarkAllRead(ctx, s.store, in.GetUserId()); err != nil {
		return nil, err
	}
	return &notifyv1.ReadAllNotificationsReply{}, nil
}
