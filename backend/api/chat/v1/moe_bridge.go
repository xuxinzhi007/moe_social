package chatv1

import "backend/rpc/pb/moe"

func PrivateMessageFromMoe(m *moe.PrivateMessage) *PrivateMessage {
	if m == nil {
		return nil
	}
	return &PrivateMessage{
		Id: m.GetId(), SenderId: m.GetSenderId(), ReceiverId: m.GetReceiverId(),
		Body: m.GetBody(), ImagePaths: m.GetImagePaths(),
		RetentionDays: m.GetRetentionDays(), CreatedAt: m.GetCreatedAt(),
		ExpiresAt: m.GetExpiresAt(), SenderMoeNo: m.GetSenderMoeNo(),
		ReceiverMoeNo: m.GetReceiverMoeNo(),
	}
}

func PrivateMessageToMoe(m *PrivateMessage) *moe.PrivateMessage {
	if m == nil {
		return nil
	}
	return &moe.PrivateMessage{
		Id: m.GetId(), SenderId: m.GetSenderId(), ReceiverId: m.GetReceiverId(),
		Body: m.GetBody(), ImagePaths: m.GetImagePaths(),
		RetentionDays: m.GetRetentionDays(), CreatedAt: m.GetCreatedAt(),
		ExpiresAt: m.GetExpiresAt(), SenderMoeNo: m.GetSenderMoeNo(),
		ReceiverMoeNo: m.GetReceiverMoeNo(),
	}
}

func PrivateMessagesFromMoe(items []*moe.PrivateMessage) []*PrivateMessage {
	if len(items) == 0 {
		return nil
	}
	out := make([]*PrivateMessage, 0, len(items))
	for _, m := range items {
		if m == nil {
			continue
		}
		out = append(out, PrivateMessageFromMoe(m))
	}
	return out
}

func PrivateMessagesToMoe(items []*PrivateMessage) []*moe.PrivateMessage {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.PrivateMessage, 0, len(items))
	for _, m := range items {
		out = append(out, PrivateMessageToMoe(m))
	}
	return out
}

func PrivateConversationFromMoe(c *moe.PrivateConversation) *PrivateConversation {
	if c == nil {
		return nil
	}
	return &PrivateConversation{
		PeerId: c.GetPeerId(), PeerName: c.GetPeerName(), PeerAvatar: c.GetPeerAvatar(),
		PeerMoeNo: c.GetPeerMoeNo(), PeerDisplayUserId: c.GetPeerDisplayUserId(),
		LastMessage: PrivateMessageFromMoe(c.GetLastMessage()), UnreadCount: c.GetUnreadCount(),
	}
}

func PrivateConversationToMoe(c *PrivateConversation) *moe.PrivateConversation {
	if c == nil {
		return nil
	}
	return &moe.PrivateConversation{
		PeerId: c.GetPeerId(), PeerName: c.GetPeerName(), PeerAvatar: c.GetPeerAvatar(),
		PeerMoeNo: c.GetPeerMoeNo(), PeerDisplayUserId: c.GetPeerDisplayUserId(),
		LastMessage: PrivateMessageToMoe(c.GetLastMessage()), UnreadCount: c.GetUnreadCount(),
	}
}

func PrivateConversationsFromMoe(items []*moe.PrivateConversation) []*PrivateConversation {
	if len(items) == 0 {
		return nil
	}
	out := make([]*PrivateConversation, 0, len(items))
	for _, c := range items {
		if c == nil {
			continue
		}
		out = append(out, PrivateConversationFromMoe(c))
	}
	return out
}

func PrivateConversationsToMoe(items []*PrivateConversation) []*moe.PrivateConversation {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.PrivateConversation, 0, len(items))
	for _, c := range items {
		out = append(out, PrivateConversationToMoe(c))
	}
	return out
}

func SendPrivateMessageRequestFromMoe(in *moe.SendPrivateMessageReq) *SendPrivateMessageRequest {
	if in == nil {
		return &SendPrivateMessageRequest{}
	}
	return &SendPrivateMessageRequest{
		SenderId: in.GetSenderId(), ReceiverId: in.GetReceiverId(),
		Body: in.GetBody(), ImagePaths: in.GetImagePaths(),
	}
}

func SendPrivateMessageRequestToMoe(in *SendPrivateMessageRequest) *moe.SendPrivateMessageReq {
	if in == nil {
		return &moe.SendPrivateMessageReq{}
	}
	return &moe.SendPrivateMessageReq{
		SenderId: in.GetSenderId(), ReceiverId: in.GetReceiverId(),
		Body: in.GetBody(), ImagePaths: in.GetImagePaths(),
	}
}

func SendPrivateMessageReplyFromMoe(out *moe.SendPrivateMessageResp) *SendPrivateMessageReply {
	if out == nil {
		return &SendPrivateMessageReply{}
	}
	return &SendPrivateMessageReply{Message: PrivateMessageFromMoe(out.GetMessage())}
}

func SendPrivateMessageReplyToMoe(out *SendPrivateMessageReply) *moe.SendPrivateMessageResp {
	if out == nil {
		return &moe.SendPrivateMessageResp{}
	}
	return &moe.SendPrivateMessageResp{Message: PrivateMessageToMoe(out.GetMessage())}
}

func ListPrivateMessagesRequestFromMoe(in *moe.ListPrivateMessagesReq) *ListPrivateMessagesRequest {
	if in == nil {
		return &ListPrivateMessagesRequest{}
	}
	return &ListPrivateMessagesRequest{
		ViewerId: in.GetViewerId(), PeerId: in.GetPeerId(),
		BeforeId: in.GetBeforeId(), Limit: in.GetLimit(),
	}
}

func ListPrivateMessagesRequestToMoe(in *ListPrivateMessagesRequest) *moe.ListPrivateMessagesReq {
	if in == nil {
		return &moe.ListPrivateMessagesReq{}
	}
	return &moe.ListPrivateMessagesReq{
		ViewerId: in.GetViewerId(), PeerId: in.GetPeerId(),
		BeforeId: in.GetBeforeId(), Limit: in.GetLimit(),
	}
}

func ListPrivateMessagesReplyFromMoe(out *moe.ListPrivateMessagesResp) *ListPrivateMessagesReply {
	if out == nil {
		return &ListPrivateMessagesReply{}
	}
	return &ListPrivateMessagesReply{
		Messages: PrivateMessagesFromMoe(out.GetMessages()), HasMore: out.GetHasMore(),
	}
}

func ListPrivateMessagesReplyToMoe(out *ListPrivateMessagesReply) *moe.ListPrivateMessagesResp {
	if out == nil {
		return &moe.ListPrivateMessagesResp{}
	}
	return &moe.ListPrivateMessagesResp{
		Messages: PrivateMessagesToMoe(out.GetMessages()), HasMore: out.GetHasMore(),
	}
}

func ListPrivateConversationsRequestFromMoe(in *moe.ListPrivateConversationsReq) *ListPrivateConversationsRequest {
	if in == nil {
		return &ListPrivateConversationsRequest{}
	}
	return &ListPrivateConversationsRequest{
		ViewerId: in.GetViewerId(), Limit: in.GetLimit(), Offset: in.GetOffset(),
	}
}

func ListPrivateConversationsRequestToMoe(in *ListPrivateConversationsRequest) *moe.ListPrivateConversationsReq {
	if in == nil {
		return &moe.ListPrivateConversationsReq{}
	}
	return &moe.ListPrivateConversationsReq{
		ViewerId: in.GetViewerId(), Limit: in.GetLimit(), Offset: in.GetOffset(),
	}
}

func ListPrivateConversationsReplyFromMoe(out *moe.ListPrivateConversationsResp) *ListPrivateConversationsReply {
	if out == nil {
		return &ListPrivateConversationsReply{}
	}
	return &ListPrivateConversationsReply{
		Conversations: PrivateConversationsFromMoe(out.GetConversations()),
		Total: out.GetTotal(), Limit: out.GetLimit(), Offset: out.GetOffset(),
		HasMore: out.GetHasMore(),
	}
}

func ListPrivateConversationsReplyToMoe(out *ListPrivateConversationsReply) *moe.ListPrivateConversationsResp {
	if out == nil {
		return &moe.ListPrivateConversationsResp{}
	}
	return &moe.ListPrivateConversationsResp{
		Conversations: PrivateConversationsToMoe(out.GetConversations()),
		Total: out.GetTotal(), Limit: out.GetLimit(), Offset: out.GetOffset(),
		HasMore: out.GetHasMore(),
	}
}
