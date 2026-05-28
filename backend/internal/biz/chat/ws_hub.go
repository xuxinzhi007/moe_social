package chatbiz

import (
	"encoding/json"
	"sync"

	"github.com/gorilla/websocket"
)

// NotificationMessage WebSocket 通知 envelope。
type NotificationMessage struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

// PushInput 单用户推送参数。
type PushInput struct {
	UserID string
	Type   string
	Data   interface{}
}

// BatchPushInput 批量推送参数。
type BatchPushInput struct {
	UserIDs []string
	Type    string
	Data    interface{}
}

// BroadcastPushInput 广播推送参数。
type BroadcastPushInput struct {
	Type string
	Data interface{}
}

var (
	userConnections  = make(map[string]*websocket.Conn)
	connectionsMutex sync.RWMutex
)

// RegisterWSConnection 注册远程 WS 连接。
func RegisterWSConnection(userID string, conn *websocket.Conn) {
	connectionsMutex.Lock()
	userConnections[userID] = conn
	connectionsMutex.Unlock()
}

// UnregisterWSConnection 移除远程 WS 连接。
func UnregisterWSConnection(userID string) {
	connectionsMutex.Lock()
	delete(userConnections, userID)
	connectionsMutex.Unlock()
}

// SendRawToUser 发送 notification envelope，data 直接作为 Data 字段。
func SendRawToUser(userID string, data interface{}) bool {
	connectionsMutex.RLock()
	conn, ok := userConnections[userID]
	connectionsMutex.RUnlock()
	if !ok {
		return false
	}

	message := NotificationMessage{Type: "notification", Data: data}
	msgData, err := json.Marshal(message)
	if err != nil {
		return false
	}

	if err := conn.WriteMessage(websocket.TextMessage, msgData); err != nil {
		connectionsMutex.Lock()
		delete(userConnections, userID)
		connectionsMutex.Unlock()
		_ = conn.Close()
		return false
	}
	return true
}

// PushToUser 向在线用户推送通知。
func PushToUser(in PushInput) bool {
	return SendRawToUser(in.UserID, map[string]interface{}{
		"type": in.Type,
		"data": in.Data,
	})
}

// PushBatch 批量推送，返回成功数。
func PushBatch(in BatchPushInput) int {
	success := 0
	for _, userID := range in.UserIDs {
		if PushToUser(PushInput{UserID: userID, Type: in.Type, Data: in.Data}) {
			success++
		}
	}
	return success
}

// BroadcastPush 广播推送，返回成功数。
func BroadcastPush(in BroadcastPushInput) int {
	success := 0
	connectionsMutex.RLock()
	userIDs := make([]string, 0, len(userConnections))
	for userID := range userConnections {
		userIDs = append(userIDs, userID)
	}
	connectionsMutex.RUnlock()

	for _, userID := range userIDs {
		if PushToUser(PushInput{UserID: userID, Type: in.Type, Data: in.Data}) {
			success++
		}
	}
	return success
}
