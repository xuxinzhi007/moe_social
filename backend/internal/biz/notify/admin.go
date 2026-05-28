package notifybiz

import (
	"context"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// Broadcast 向全部用户广播系统通知。
func Broadcast(ctx context.Context, st NotifyStore, title, content string) (int32, error) {
	if st == nil {
		return 0, gorm.ErrInvalidDB
	}
	body := SystemNotificationContent(title, content)
	if body == "" {
		return 0, ErrEmptyContent
	}

	st = st.WithContext(ctx)
	userIDs, err := st.ListAllUserIDs(ctx)
	if err != nil {
		return 0, err
	}

	created := int32(0)
	for _, uid := range userIDs {
		n := model.Notification{
			UserID:   uid,
			SenderID: 0,
			Type:     AdminSystemNotificationType,
			Content:  body,
			IsRead:   false,
		}
		if err := st.CreateNotification(ctx, &n, true); err != nil {
			continue
		}
		created++
	}
	return created, nil
}

// SendToUser 向指定用户发送系统通知。
func SendToUser(ctx context.Context, st NotifyStore, userIDRaw, title, content string) (uint, error) {
	if st == nil {
		return 0, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 64)
	if err != nil || userID == 0 {
		return 0, ErrInvalidUserID
	}
	body := SystemNotificationContent(title, content)
	if body == "" {
		return 0, ErrEmptyContent
	}

	st = st.WithContext(ctx)
	if _, err := st.GetUser(ctx, uint(userID)); err != nil {
		return 0, err
	}

	n := model.Notification{
		UserID:   uint(userID),
		SenderID: 0,
		Type:     AdminSystemNotificationType,
		Content:  body,
		IsRead:   false,
	}
	if err := st.CreateNotification(ctx, &n, true); err != nil {
		return 0, err
	}
	return n.ID, nil
}
