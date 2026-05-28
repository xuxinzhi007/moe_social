package notifybiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// NotifyStore 通知持久化（P4-D4；默认由 internal/data/notify 实现）。
type NotifyStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) NotifyStore

	ListInbox(ctx context.Context, userID uint, offset, limit int) ([]model.Notification, int64, error)
	CountUnread(ctx context.Context, userID uint) (int64, error)
	MarkRead(ctx context.Context, userID, notificationID uint) error
	MarkAllRead(ctx context.Context, userID uint) error
	CreateNotification(ctx context.Context, notification *model.Notification, omitPostID bool) error

	ListAllUserIDs(ctx context.Context) ([]uint, error)
	GetUser(ctx context.Context, userID uint) (model.User, error)
}
