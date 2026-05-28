package chat

import chatbiz "backend/internal/biz/chat"

// NotificationMessage WS 通知 envelope（兼容旧引用）。
type NotificationMessage = chatbiz.NotificationMessage

// SendNotificationReq 单用户 WS 通知。
type SendNotificationReq struct {
	UserID string
	Type   string
	Data   interface{}
}

// SendBatchNotificationReq 批量 WS 通知。
type SendBatchNotificationReq struct {
	UserIDs []string
	Type    string
	Data    interface{}
}

// BroadcastNotificationReq 广播 WS 通知。
type BroadcastNotificationReq struct {
	Type string
	Data interface{}
}

// SendWSNotification 向在线 /ws/remote 用户推送通知。
func SendWSNotification(req *SendNotificationReq) bool {
	if req == nil {
		return false
	}
	return chatbiz.PushToUser(chatbiz.PushInput{UserID: req.UserID, Type: req.Type, Data: req.Data})
}

// SendWSBatchNotification 批量推送，返回成功数。
func SendWSBatchNotification(req *SendBatchNotificationReq) int {
	if req == nil {
		return 0
	}
	return chatbiz.PushBatch(chatbiz.BatchPushInput{UserIDs: req.UserIDs, Type: req.Type, Data: req.Data})
}

// BroadcastWSNotification 广播推送，返回成功数。
func BroadcastWSNotification(req *BroadcastNotificationReq) int {
	if req == nil {
		return 0
	}
	return chatbiz.BroadcastPush(chatbiz.BroadcastPushInput{Type: req.Type, Data: req.Data})
}
