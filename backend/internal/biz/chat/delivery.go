package chatbiz

import (
	"context"
	"strings"
	"time"

	notifybiz "backend/internal/biz/notify"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
	"google.golang.org/grpc"
)

// NotificationTypePrivateChat 与 model.Notification.Type 一致：6=私信。
const NotificationTypePrivateChat = 6

// UserProfileReader 查询用户展示资料。
type UserProfileReader interface {
	GetUser(ctx context.Context, in *moe.GetUserReq, opts ...grpc.CallOption) (*moe.GetUserResp, error)
}

// NotificationWriter 离线通知写入（RPC 兜底）。
type NotificationWriter interface {
	CreateNotification(ctx context.Context, in *moe.CreateNotificationReq, opts ...grpc.CallOption) (*moe.CreateNotificationResp, error)
}

// DeliveryDeps 私信实时投递依赖。
type DeliveryDeps struct {
	UserReader  UserProfileReader
	NotifyStore notifybiz.NotifyStore
	NotifyRPC   NotificationWriter
}

// ResolvePrivateMessageSenderProfile 私信投递时的展示名与头像。
func ResolvePrivateMessageSenderProfile(
	ctx context.Context,
	deps DeliveryDeps,
	senderID string,
	protoMsg *moe.PrivateMessage,
	clientAvatar string,
) (senderName string, senderAvatar string) {
	senderAvatar = strings.TrimSpace(clientAvatar)
	senderName = ""
	var username string
	if deps.UserReader != nil {
		rpcResp, err := deps.UserReader.GetUser(ctx, &moe.GetUserReq{UserId: senderID})
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
		senderName = "用户"
	}
	return senderName, senderAvatar
}

// PersistOfflinePrivateChatNotification 对端无 WS 时写入通知中心。
func PersistOfflinePrivateChatNotification(ctx context.Context, deps DeliveryDeps, targetUserID, fromUserID, content, senderName string) {
	body := strings.TrimSpace(content)
	if body == "" || targetUserID == fromUserID {
		return
	}
	if len(body) > 200 {
		body = body[:200]
	}
	if senderName != "" && senderName != "用户" {
		body = senderName + ": " + body
		if len(body) > 200 {
			body = body[:200]
		}
	}
	req := &moe.CreateNotificationReq{
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
		logx.WithContext(ctx).Errorf("offline private chat notify to=%s from=%s: %v", targetUserID, fromUserID, err)
		return
	}
	logx.WithContext(ctx).Debugf("offline private chat notification to=%s from=%s", targetUserID, fromUserID)
}

// DeliverPrivateMessageRealTime 私信写入 DB 后 WS 推送接收方，失败则通知兜底。
func DeliverPrivateMessageRealTime(
	ctx context.Context,
	deps DeliveryDeps,
	senderID, receiverID, content, senderName, senderAvatar string,
	protoMsg *moe.PrivateMessage,
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
