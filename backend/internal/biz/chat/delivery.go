package chatbiz

import (
	"context"
	"strings"
	"time"

	chatv1 "backend/api/chat/v1"
	userv1 "backend/api/user/v1"
	notifybiz "backend/internal/biz/notify"

	"backend/internal/platform/moelog"
)

// NotificationTypePrivateChat ?? model.Notification.Type ???????6=?????
const NotificationTypePrivateChat = 6

// UserProfileReader ?????????????????????
type UserProfileReader interface {
	GetUser(ctx context.Context, in *userv1.GetUserReq) (*userv1.GetUserResp, error)
}

// NotificationWriter ????????????????RPC ??????????
type NotificationWriter interface {
	CreateNotification(ctx context.Context, in *userv1.CreateNotificationReq) (*userv1.CreateNotificationResp, error)
}

// DeliveryDeps ???????????????????
type DeliveryDeps struct {
	UserReader  UserProfileReader
	NotifyStore notifybiz.NotifyStore
	NotifyRPC   NotificationWriter
}

// ResolvePrivateMessageSenderProfile ???????????????????????????
func ResolvePrivateMessageSenderProfile(
	ctx context.Context,
	deps DeliveryDeps,
	senderID string,
	protoMsg *chatv1.PrivateMessage,
	clientAvatar string,
) (senderName string, senderAvatar string) {
	senderAvatar = strings.TrimSpace(clientAvatar)
	senderName = ""
	var username string
	if deps.UserReader != nil {
		rpcResp, err := deps.UserReader.GetUser(ctx, &userv1.GetUserReq{UserId: senderID})
		if err == nil && rpcResp != nil && rpcResp.User != nil {
			u := rpcResp.User
			username = strings.TrimSpace(u.Username)
			if senderAvatar == "" {
				if av := strings.TrimSpace(u.Avatar); av != "" {
					senderAvatar = av
				}
			}
		}
	}
	if username != "" {
		senderName = username
	} else if protoMsg != nil {
		if m := strings.TrimSpace(protoMsg.SenderMoeNo); m != "" {
			senderName = m
		}
	}
	if senderName == "" {
		senderName = "??????"
	}
	return senderName, senderAvatar
}

// PersistOfflinePrivateChatNotification ????? WS ?????????????????????
func PersistOfflinePrivateChatNotification(ctx context.Context, deps DeliveryDeps, targetUserID, fromUserID, content, senderName string) {
	body := strings.TrimSpace(content)
	if body == "" || targetUserID == fromUserID {
		return
	}
	if len(body) > 200 {
		body = body[:200]
	}
	if senderName != "" && senderName != "??????" {
		body = senderName + ": " + body
		if len(body) > 200 {
			body = body[:200]
		}
	}
	req := &userv1.CreateNotificationReq{
		UserId:   targetUserID,
		SenderId: fromUserID,
		Type:     NotificationTypePrivateChat,
		PostId:   "",
		Content:  body,
	}
	var err error
	if deps.NotifyStore != nil {
		err = notifybiz.CreateInbox(ctx, deps.NotifyStore, req)
	} else if deps.NotifyRPC != nil {
		_, err = deps.NotifyRPC.CreateNotification(ctx, req)
	}
	if err != nil {
		moelog.Errorf("offline private chat notify to=%s from=%s: %v", targetUserID, fromUserID, err)
		return
	}
	moelog.Infof("offline private chat notification to=%s from=%s", targetUserID, fromUserID)
}

// DeliverPrivateMessageRealTime ???????? DB ?? WS ????????????????????????????????????
func DeliverPrivateMessageRealTime(
	ctx context.Context,
	deps DeliveryDeps,
	senderID, receiverID, content, senderName, senderAvatar string,
	protoMsg *chatv1.PrivateMessage,
) {
	senderKey := NormalizeChatUserIDKey(senderID)
	recvKey := NormalizeChatUserIDKey(receiverID)
	now := time.Now()
	chatMsg := map[string]interface{}{
		"from":          senderKey,
		"content":       content,
		"time":          now.Format(time.RFC3339),
		"timestamp":     now.UnixMilli(),
		"sender_name":   senderName,
		"sender_avatar": senderAvatar,
		"senderName":    senderName,
		"senderAvatar":  senderAvatar,
	}
	if protoMsg != nil && protoMsg.Id != "" {
		chatMsg["server_message_id"] = protoMsg.Id
		chatMsg["expires_at"] = protoMsg.ExpiresAt
		if protoMsg.SenderMoeNo != "" {
			chatMsg["sender_moe_no"] = protoMsg.SenderMoeNo
		}
		if protoMsg.ReceiverMoeNo != "" {
			chatMsg["receiver_moe_no"] = protoMsg.ReceiverMoeNo
		}
	}
	if !PushJSONToChatUser(recvKey, chatMsg) {
		PersistOfflinePrivateChatNotification(ctx, deps, recvKey, senderKey, content, senderName)
	}
}
