package chatapp

import (
	"context"
	chatbiz "backend/internal/biz/chat"
)

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
