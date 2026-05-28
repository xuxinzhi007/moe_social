//go:build hybrid

package handlerutil

import chatbiz "backend/internal/biz/chat"

// SendWSNotification 向在线 /ws/remote 用户推送通知。
func SendWSNotification(userID, typ string, data interface{}) bool {
	return chatbiz.PushToUser(chatbiz.PushInput{UserID: userID, Type: typ, Data: data})
}

// SendWSBatchNotification 批量推送，返回成功数。
func SendWSBatchNotification(userIDs []string, typ string, data interface{}) int {
	return chatbiz.PushBatch(chatbiz.BatchPushInput{UserIDs: userIDs, Type: typ, Data: data})
}

// BroadcastWSNotification 广播推送，返回成功数。
func BroadcastWSNotification(typ string, data interface{}) int {
	return chatbiz.BroadcastPush(chatbiz.BroadcastPushInput{Type: typ, Data: data})
}
