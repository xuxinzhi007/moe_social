package giftbiz

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	userv1 "backend/api/user/v1"
	chatbiz "backend/internal/biz/chat"
	notifybiz "backend/internal/biz/notify"
	"backend/internal/platform/moelog"
	"backend/model"
)

// DeliverGiftReceived notifies the receiver in real time; persists inbox when offline.
func DeliverGiftReceived(
	ctx context.Context,
	notifyStore notifybiz.NotifyStore,
	receiverID uint,
	sender model.User,
	gift model.Gift,
	quantity int32,
) {
	if receiverID == 0 {
		return
	}
	recvKey := chatbiz.NormalizeChatUserIDKey(strconv.FormatUint(uint64(receiverID), 10))
	senderKey := chatbiz.NormalizeChatUserIDKey(strconv.FormatUint(uint64(sender.ID), 10))

	senderName := strings.TrimSpace(sender.Username)
	if senderName == "" {
		senderName = "用户"
	}
	senderAvatar := strings.TrimSpace(sender.Avatar)

	if quantity <= 0 {
		quantity = 1
	}

	payload := map[string]interface{}{
		"type":          "gift_received",
		"from_user_id":  senderKey,
		"sender_name":   senderName,
		"sender_avatar": senderAvatar,
		"senderName":    senderName,
		"senderAvatar":  senderAvatar,
		"quantity":      quantity,
		"gift": map[string]interface{}{
			"id":          strconv.FormatUint(uint64(gift.ID), 10),
			"name":        gift.Name,
			"icon":        gift.Icon,
			"price":       gift.Price,
			"category":    gift.Category,
			"description": gift.Description,
			"sort_order":  gift.SortOrder,
		},
	}

	if !chatbiz.PushJSONToChatUser(recvKey, payload) {
		persistOfflineGiftNotification(ctx, notifyStore, receiverID, sender.ID, gift, quantity)
	}
}

func persistOfflineGiftNotification(
	ctx context.Context,
	st notifybiz.NotifyStore,
	receiverID, senderID uint,
	gift model.Gift,
	quantity int32,
) {
	if st == nil {
		return
	}
	content := fmt.Sprintf("送你「%s」", gift.Name)
	if quantity > 1 {
		content = fmt.Sprintf("送你「%s」×%d", gift.Name, quantity)
	}

	req := &userv1.CreateNotificationReq{
		UserId:   strconv.FormatUint(uint64(receiverID), 10),
		SenderId: strconv.FormatUint(uint64(senderID), 10),
		Type:     notifybiz.NotificationTypeGiftReceived,
		PostId:   strconv.FormatUint(uint64(gift.ID), 10),
		Content:  content,
	}
	if err := notifybiz.CreateInbox(ctx, st, req); err != nil {
		moelog.Errorf(
			"offline gift notify to=%d from=%d gift=%d: %v",
			receiverID, senderID, gift.ID, err,
		)
		return
	}
	moelog.Infof("offline gift notification to=%d from=%d gift=%s", receiverID, senderID, gift.Name)
}
