package notifybiz

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// InboxPage 通知分页。
type InboxPage struct {
	Page     int32
	PageSize int32
}

func parseUserID32(raw string) (uint, error) {
	n, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 32)
	if err != nil || n == 0 {
		return 0, ErrInvalidUserID
	}
	return uint(n), nil
}

func parseNotificationID(raw string) (uint, error) {
	n, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 32)
	if err != nil || n == 0 {
		return 0, ErrInvalidNotificationID
	}
	return uint(n), nil
}

// ListInbox 用户通知列表。
func ListInbox(ctx context.Context, st NotifyStore, userIDRaw string, page InboxPage) ([]*moe.Notification, int32, error) {
	if st == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	userID, err := parseUserID32(userIDRaw)
	if err != nil {
		return nil, 0, err
	}
	p := page.Page
	if p < 1 {
		p = 1
	}
	ps := page.PageSize
	if ps < 1 {
		ps = 10
	}
	offset := int((p - 1) * ps)

	st = st.WithContext(ctx)
	rows, total, err := st.ListInbox(ctx, userID, offset, int(ps))
	if err != nil {
		return nil, 0, err
	}
	out := make([]*moe.Notification, 0, len(rows))
	for i := range rows {
		out = append(out, modelToProto(&rows[i]))
	}
	return out, int32(total), nil
}

// UnreadCount 未读数量。
func UnreadCount(ctx context.Context, st NotifyStore, userIDRaw string) (int32, error) {
	if st == nil {
		return 0, gorm.ErrInvalidDB
	}
	userID, err := parseUserID32(userIDRaw)
	if err != nil {
		return 0, err
	}
	count, err := st.WithContext(ctx).CountUnread(ctx, userID)
	if err != nil {
		return 0, err
	}
	return int32(count), nil
}

// MarkRead 标记单条已读。
func MarkRead(ctx context.Context, st NotifyStore, userIDRaw, notificationIDRaw string) error {
	if st == nil {
		return gorm.ErrInvalidDB
	}
	userID, err := parseUserID32(userIDRaw)
	if err != nil {
		return err
	}
	nid, err := parseNotificationID(notificationIDRaw)
	if err != nil {
		return err
	}
	return st.WithContext(ctx).MarkRead(ctx, userID, nid)
}

// MarkAllRead 全部已读。
func MarkAllRead(ctx context.Context, st NotifyStore, userIDRaw string) error {
	if st == nil {
		return gorm.ErrInvalidDB
	}
	userID, err := parseUserID32(userIDRaw)
	if err != nil {
		return err
	}
	return st.WithContext(ctx).MarkAllRead(ctx, userID)
}

// CreateInbox 写入一条用户通知（等同 CreateNotification RPC）。
func CreateInbox(ctx context.Context, st NotifyStore, in *moe.CreateNotificationReq) error {
	if st == nil {
		return gorm.ErrInvalidDB
	}
	userID, err := parseUserID32(in.GetUserId())
	if err != nil {
		return err
	}
	senderID, err := parseUserID32(in.GetSenderId())
	if err != nil {
		return err
	}

	var postID uint
	if raw := strings.TrimSpace(in.GetPostId()); raw != "" {
		n, err := strconv.ParseUint(raw, 10, 32)
		if err != nil {
			return ErrInvalidNotificationID
		}
		postID = uint(n)
	}

	content := in.GetContent()
	if len(content) > 200 {
		content = content[:200]
	}

	notification := model.Notification{
		UserID:   userID,
		SenderID: senderID,
		Type:     int(in.GetType()),
		Content:  content,
		IsRead:   false,
	}
	omitPostID := postID == 0
	if postID > 0 {
		notification.PostID = postID
	}
	return st.WithContext(ctx).CreateNotification(ctx, &notification, omitPostID)
}

func modelToProto(n *model.Notification) *moe.Notification {
	if n == nil {
		return nil
	}
	senderName := "未知用户"
	if n.Sender.Username != "" {
		senderName = n.Sender.Username
	} else if n.Sender.Email != "" {
		senderName = n.Sender.Email
	}
	return &moe.Notification{
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
	}
}
