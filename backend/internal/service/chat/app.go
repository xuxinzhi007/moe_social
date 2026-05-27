// Package chatapp 私信域应用服务（F106 Hybrid）。
package chatapp

import (
	"context"

	chatbiz "backend/internal/biz/chat"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// AppService 私信应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

// SendPrivateMessage 发送私信。
func (s *AppService) SendPrivateMessage(ctx context.Context, in *super.SendPrivateMessageReq) (*super.SendPrivateMessageResp, error) {
	return chatbiz.SendPrivateMessage(ctx, s.db, in)
}

// ListPrivateMessages 私信历史。
func (s *AppService) ListPrivateMessages(ctx context.Context, in *super.ListPrivateMessagesReq) (*super.ListPrivateMessagesResp, error) {
	return chatbiz.ListPrivateMessages(ctx, s.db, in)
}

// ListPrivateConversations 会话列表。
func (s *AppService) ListPrivateConversations(ctx context.Context, in *super.ListPrivateConversationsReq) (*super.ListPrivateConversationsResp, error) {
	return chatbiz.ListPrivateConversations(ctx, s.db, in)
}
