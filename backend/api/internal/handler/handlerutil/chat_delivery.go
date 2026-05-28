package handlerutil

import (
	"context"

	"backend/api/internal/svc"
	chatbiz "backend/internal/biz/chat"
	"backend/rpc/pb/moe"
)

// ChatDeliveryDeps 私信/通知投递依赖。
func ChatDeliveryDeps(svc *svc.ServiceContext) chatbiz.DeliveryDeps {
	deps := chatbiz.DeliveryDeps{UserReader: svc.UserGW, NotifyRPC: svc.UserGW}
	if svc.UserApp != nil {
		deps.NotifyStore = svc.UserApp.Notify()
	}
	return deps
}

// ChatWSDeps 构建 Chat WS 服务依赖。
func ChatWSDeps(svcCtx *svc.ServiceContext) chatbiz.ChatWSDeps {
	deps := chatbiz.ChatWSDeps{
		PM:       svcCtx.ChatGW,
		Delivery: ChatDeliveryDeps(svcCtx),
	}
	return deps
}

// PushJSONToChatUser 向已连接 /ws/chat 的用户推送 JSON。
func PushJSONToChatUser(userID string, data interface{}) bool {
	return chatbiz.PushJSONToChatUser(userID, data)
}

// ResolvePrivateMessageSenderProfile 私信投递时的展示名与头像。
func ResolvePrivateMessageSenderProfile(
	ctx context.Context,
	svc *svc.ServiceContext,
	senderID string,
	protoMsg *moe.PrivateMessage,
	clientAvatar string,
) (string, string) {
	return chatbiz.ResolvePrivateMessageSenderProfile(ctx, ChatDeliveryDeps(svc), senderID, protoMsg, clientAvatar)
}

// DeliverPrivateMessageRealTime 私信写入 DB 后 WS 推送接收方。
func DeliverPrivateMessageRealTime(
	ctx context.Context,
	svc *svc.ServiceContext,
	senderID, receiverID, content, senderName, senderAvatar string,
	protoMsg *moe.PrivateMessage,
) {
	chatbiz.DeliverPrivateMessageRealTime(ctx, ChatDeliveryDeps(svc), senderID, receiverID, content, senderName, senderAvatar, protoMsg)
}
