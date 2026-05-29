// Package notifyapp 通知域应用服务（P4-D4）。
package notifyapp

import (
	"context"

	notifyv1 "backend/api/notify/v1"
	notifybiz "backend/internal/biz/notify"
	notifydata "backend/internal/data/notify"

	"gorm.io/gorm"
)

// AppService 通知应用层。
type AppService struct {
	store notifybiz.NotifyStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: notifydata.NewStore(db)}
}

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

// Broadcast 全员广播。
func (s *AppService) Broadcast(ctx context.Context, title, content string) (int32, error) {
	return notifybiz.Broadcast(ctx, s.store, title, content)
}

// SendToUser 单用户系统通知。
func (s *AppService) SendToUser(ctx context.Context, userID, title, content string) (uint, error) {
	return notifybiz.SendToUser(ctx, s.store, userID, title, content)
}

// Store 返回持久化接口（Hybrid 内部复用）。
func (s *AppService) Store() notifybiz.NotifyStore {
	if s == nil {
		return nil
	}
	return s.store
}
