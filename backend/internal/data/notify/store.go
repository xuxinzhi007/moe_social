package notifydata

import (
	"context"
	"errors"

	notifybiz "backend/internal/biz/notify"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.NotifyStore（P4-D4）。
func NewStore(db *gorm.DB) notifybiz.NotifyStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) notifybiz.NotifyStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) ListInbox(ctx context.Context, userID uint, offset, limit int) ([]model.Notification, int64, error) {
	base := s.db.WithContext(ctx).Model(&model.Notification{}).Where("user_id = ?", userID)
	var total int64
	if err := base.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.Notification
	err := base.Order("created_at desc").Offset(offset).Limit(limit).Preload("Sender").Find(&rows).Error
	return rows, total, err
}

func (s *store) CountUnread(ctx context.Context, userID uint) (int64, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&model.Notification{}).
		Where("user_id = ? AND is_read = ?", userID, false).
		Count(&count).Error
	return count, err
}

func (s *store) MarkRead(ctx context.Context, userID, notificationID uint) error {
	return s.db.WithContext(ctx).Model(&model.Notification{}).
		Where("id = ? AND user_id = ?", notificationID, userID).
		Update("is_read", true).Error
}

func (s *store) MarkAllRead(ctx context.Context, userID uint) error {
	return s.db.WithContext(ctx).Model(&model.Notification{}).
		Where("user_id = ? AND is_read = ?", userID, false).
		Update("is_read", true).Error
}

func (s *store) CreateNotification(ctx context.Context, notification *model.Notification, omitPostID bool) error {
	q := s.db.WithContext(ctx)
	if omitPostID {
		q = q.Omit("PostID")
	}
	return q.Create(notification).Error
}

func (s *store) ListAllUserIDs(ctx context.Context) ([]uint, error) {
	var userIDs []uint
	err := s.db.WithContext(ctx).Model(&model.User{}).Pluck("id", &userIDs).Error
	return userIDs, err
}

func (s *store) GetUser(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, notifybiz.ErrUserNotFound
	}
	return user, err
}
