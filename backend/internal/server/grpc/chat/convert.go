package chatgrpc

import (
	chatv1 "backend/api/chat/v1"
	moerpc "backend/rpc/pb/moe"
)

func privateMessagesToProto(items []*moerpc.PrivateMessage) []*chatv1.PrivateMessage {
	if len(items) == 0 {
		return nil
	}
	out := make([]*chatv1.PrivateMessage, 0, len(items))
	for _, m := range items {
		out = append(out, privateMessageToProto(m))
	}
	return out
}

func privateMessageToProto(m *moerpc.PrivateMessage) *chatv1.PrivateMessage {
	if m == nil {
		return nil
	}
	return &chatv1.PrivateMessage{
		Id: m.GetId(), SenderId: m.GetSenderId(), ReceiverId: m.GetReceiverId(),
		Body: m.GetBody(), ImagePaths: m.GetImagePaths(),
		RetentionDays: m.GetRetentionDays(), CreatedAt: m.GetCreatedAt(),
		ExpiresAt: m.GetExpiresAt(), SenderMoeNo: m.GetSenderMoeNo(),
		ReceiverMoeNo: m.GetReceiverMoeNo(),
	}
}

func conversationsToProto(items []*moerpc.PrivateConversation) []*chatv1.PrivateConversation {
	if len(items) == 0 {
		return nil
	}
	out := make([]*chatv1.PrivateConversation, 0, len(items))
	for _, c := range items {
		out = append(out, conversationToProto(c))
	}
	return out
}

func conversationToProto(c *moerpc.PrivateConversation) *chatv1.PrivateConversation {
	if c == nil {
		return nil
	}
	return &chatv1.PrivateConversation{
		PeerId: c.GetPeerId(), PeerName: c.GetPeerName(), PeerAvatar: c.GetPeerAvatar(),
		PeerMoeNo: c.GetPeerMoeNo(), PeerDisplayUserId: c.GetPeerDisplayUserId(),
		LastMessage: privateMessageToProto(c.GetLastMessage()), UnreadCount: c.GetUnreadCount(),
	}
}
