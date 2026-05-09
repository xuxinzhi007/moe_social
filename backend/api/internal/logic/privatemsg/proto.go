package privatemsg

import (
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func privateMessageItemFromProto(m *super.PrivateMessage) types.PrivateMessageItem {
	paths := m.GetImagePaths()
	if paths == nil {
		paths = []string{}
	}
	return types.PrivateMessageItem{
		Id:            m.GetId(),
		SenderId:      m.GetSenderId(),
		ReceiverId:    m.GetReceiverId(),
		SenderMoeNo:   m.GetSenderMoeNo(),
		ReceiverMoeNo: m.GetReceiverMoeNo(),
		Body:          m.GetBody(),
		ImagePaths:    paths,
		RetentionDays: int(m.GetRetentionDays()),
		CreatedAt:     m.GetCreatedAt(),
		ExpiresAt:     m.GetExpiresAt(),
	}
}

func privateConversationItemFromProto(c *super.PrivateConversation) types.PrivateConversationItem {
	last := types.PrivateMessageItem{}
	if c != nil && c.LastMessage != nil {
		last = privateMessageItemFromProto(c.LastMessage)
	}
	if c == nil {
		return types.PrivateConversationItem{LastMessage: last}
	}
	return types.PrivateConversationItem{
		PeerUserId:        c.GetPeerId(),
		PeerName:          c.GetPeerName(),
		PeerAvatar:        c.GetPeerAvatar(),
		PeerMoeNo:         c.GetPeerMoeNo(),
		PeerDisplayUserId: c.GetPeerDisplayUserId(),
		LastMessage:       last,
		UnreadCount:       int(c.GetUnreadCount()),
	}
}
