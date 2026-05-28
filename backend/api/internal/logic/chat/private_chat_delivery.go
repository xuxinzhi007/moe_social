package chat

import (
	"context"

	chatbiz "backend/internal/biz/chat"
	"backend/api/internal/svc"
	"backend/rpc/pb/moe"
)

// NotificationTypePrivateChat 与 model.Notification.Type 一致：6=私信。
const NotificationTypePrivateChat = chatbiz.NotificationTypePrivateChat

// PeerUserIDFromChatMessage 解析 WS 私信目标用户 id。
func PeerUserIDFromChatMessage(msg map[string]interface{}) (string, bool) {
	return chatbiz.PeerUserIDFromChatMessage(msg)
}

// NormalizeChatUserIDKey 将用户主键规范为十进制字符串。
func NormalizeChatUserIDKey(s string) string {
	return chatbiz.NormalizeChatUserIDKey(s)
}

// PushJSONToChatUser 向已连接 /ws/chat 的用户推送一条 JSON。
func PushJSONToChatUser(userID string, data interface{}) bool {
	return chatbiz.PushJSONToChatUser(userID, data)
}

func deliveryDeps(svc *svc.ServiceContext) chatbiz.DeliveryDeps {
	deps := chatbiz.DeliveryDeps{UserReader: svc.UserGW, NotifyRPC: svc.UserGW}
	if svc.UserApp != nil {
		deps.DB = svc.UserApp.DB()
	}
	return deps
}

// ResolvePrivateMessageSenderProfile 私信投递时的展示名与头像。
func ResolvePrivateMessageSenderProfile(
	ctx context.Context,
	svc *svc.ServiceContext,
	senderID string,
	protoMsg *moe.PrivateMessage,
	clientAvatar string,
) (senderName string, senderAvatar string) {
	return chatbiz.ResolvePrivateMessageSenderProfile(ctx, deliveryDeps(svc), senderID, protoMsg, clientAvatar)
}

// PersistOfflinePrivateChatNotification 对端无 WS 时写入通知中心。
func PersistOfflinePrivateChatNotification(ctx context.Context, svc *svc.ServiceContext, targetUserID, fromUserID, content, senderName string) {
	chatbiz.PersistOfflinePrivateChatNotification(ctx, deliveryDeps(svc), targetUserID, fromUserID, content, senderName)
}

// DeliverPrivateMessageRealTime 私信写入 DB 后 WS 推送接收方。
func DeliverPrivateMessageRealTime(ctx context.Context, svc *svc.ServiceContext, senderID, receiverID, content, senderName, senderAvatar string, protoMsg *moe.PrivateMessage) {
	chatbiz.DeliverPrivateMessageRealTime(ctx, deliveryDeps(svc), senderID, receiverID, content, senderName, senderAvatar, protoMsg)
}
