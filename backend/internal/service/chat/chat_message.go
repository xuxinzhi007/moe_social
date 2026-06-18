package chatapp

import (
	"context"
	chatv1 "backend/api/chat/v1"
	chatbiz "backend/internal/biz/chat"
)

// SendPrivateMessage 发送私信。
func (s *AppService) SendPrivateMessage(ctx context.Context, in *chatv1.SendPrivateMessageRequest) (*chatv1.SendPrivateMessageReply, error) {
	return chatbiz.SendPrivateMessage(ctx, s.pm, in)
}

// ListPrivateMessages 私信历史。
func (s *AppService) ListPrivateMessages(ctx context.Context, in *chatv1.ListPrivateMessagesRequest) (*chatv1.ListPrivateMessagesReply, error) {
	return chatbiz.ListPrivateMessages(ctx, s.pm, in)
}

// ListPrivateConversations 会话列表。
func (s *AppService) ListPrivateConversations(ctx context.Context, in *chatv1.ListPrivateConversationsRequest) (*chatv1.ListPrivateConversationsReply, error) {
	return chatbiz.ListPrivateConversations(ctx, s.pm, in)
}
