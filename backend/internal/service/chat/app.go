// Package chatapp 私信域应用服务（F106 Hybrid）。
package chatapp

import (
	"context"

	chatv1 "backend/api/chat/v1"
	chatbiz "backend/internal/biz/chat"
	chatdata "backend/internal/data/chat"

	"gorm.io/gorm"
)

// AppService 私信应用层。
type AppService struct {
	pm chatbiz.PrivateMessageStore
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{pm: chatdata.NewStore(db), db: db}
}

// DB 返回私信域数据库连接（离线通知兜底等）。
func (s *AppService) DB() *gorm.DB {
	if s == nil {
		return nil
	}
	return s.db
}

// PrivateMessageStore 返回私信持久化接口。
func (s *AppService) PrivateMessageStore() chatbiz.PrivateMessageStore {
	if s == nil {
		return nil
	}
	return s.pm
}

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

// PushNotification 向在线用户推送 WS 通知。
func (s *AppService) PushNotification(_ context.Context, userID, nType string, data interface{}) bool {
	return chatbiz.PushToUser(chatbiz.PushInput{UserID: userID, Type: nType, Data: data})
}

// PushBatchNotification 批量推送 WS 通知。
func (s *AppService) PushBatchNotification(_ context.Context, userIDs []string, nType string, data interface{}) int {
	return chatbiz.PushBatch(chatbiz.BatchPushInput{UserIDs: userIDs, Type: nType, Data: data})
}

// BroadcastPushNotification 广播 WS 通知。
func (s *AppService) BroadcastPushNotification(_ context.Context, nType string, data interface{}) int {
	return chatbiz.BroadcastPush(chatbiz.BroadcastPushInput{Type: nType, Data: data})
}
