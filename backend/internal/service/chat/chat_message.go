package chatapp

import (
	"context"
	"errors"
	"strconv"
	"strings"

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

// ClearPrivateChatHistory 清空双方私信历史。
func (s *AppService) ClearPrivateChatHistory(ctx context.Context, in *chatv1.ClearPrivateChatHistoryReq) (*chatv1.ClearPrivateChatHistoryResp, error) {
	viewerID, err := strconv.ParseUint(strings.TrimSpace(in.GetViewerId()), 10, 32)
	if err != nil || viewerID == 0 {
		return nil, errors.New("invalid viewer_id")
	}
	peerID, err := strconv.ParseUint(strings.TrimSpace(in.GetPeerId()), 10, 32)
	if err != nil || peerID == 0 {
		return nil, errors.New("invalid peer_id")
	}
	if err := chatbiz.ClearPrivateChatHistory(ctx, s.pm, uint(viewerID), uint(peerID)); err != nil {
		return nil, err
	}
	return &chatv1.ClearPrivateChatHistoryResp{}, nil
}
