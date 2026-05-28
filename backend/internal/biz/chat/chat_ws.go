package chatbiz

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"sync"

	"github.com/gorilla/websocket"
	"backend/internal/platform/moelog"
)

var (
	chatConnections      = make(map[string]*websocket.Conn)
	chatConnectionsMutex sync.RWMutex
)

// RegisterChatWSConnection 注册 /ws/chat 连接。
func RegisterChatWSConnection(userID string, conn *websocket.Conn) {
	key := NormalizeChatUserIDKey(userID)
	chatConnectionsMutex.Lock()
	chatConnections[key] = conn
	chatConnectionsMutex.Unlock()
}

// UnregisterChatWSConnection 移除 /ws/chat 连接。
func UnregisterChatWSConnection(userID string) {
	key := NormalizeChatUserIDKey(userID)
	chatConnectionsMutex.Lock()
	delete(chatConnections, key)
	chatConnectionsMutex.Unlock()
}

// NormalizeChatUserIDKey 将用户主键规范为十进制字符串（与 WS 注册键对齐）。
func NormalizeChatUserIDKey(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return s
	}
	u, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		return s
	}
	return strconv.FormatUint(u, 10)
}

// PushJSONToChatUser 向已连接 /ws/chat 的用户推送一条 JSON。
func PushJSONToChatUser(userID string, data interface{}) bool {
	key := NormalizeChatUserIDKey(userID)
	chatConnectionsMutex.RLock()
	conn, ok := chatConnections[key]
	chatConnectionsMutex.RUnlock()
	if !ok {
		return false
	}
	msgData, err := json.Marshal(data)
	if err != nil {
		moelog.Errorf("chat marshal to user=%s: %v", key, err)
		return false
	}
	err = conn.WriteMessage(websocket.TextMessage, msgData)
	if err != nil {
		moelog.Errorf("chat write to user=%s: %v", key, err)
		chatConnectionsMutex.Lock()
		delete(chatConnections, key)
		chatConnectionsMutex.Unlock()
		_ = conn.Close()
		return false
	}
	return true
}

func stringifyJSONScalar(v interface{}) (string, bool) {
	if v == nil {
		return "", false
	}
	switch t := v.(type) {
	case string:
		s := strings.TrimSpace(t)
		if s == "" {
			return "", false
		}
		return s, true
	case float64:
		s := strconv.FormatFloat(t, 'f', 0, 64)
		if s == "" || s == "0" {
			return "", false
		}
		return s, true
	case json.Number:
		s := strings.TrimSpace(t.String())
		if s == "" {
			return "", false
		}
		return s, true
	default:
		s := strings.TrimSpace(fmt.Sprint(t))
		if s == "" || s == "<nil>" {
			return "", false
		}
		return s, true
	}
}

// PeerUserIDFromChatMessage 解析 WS 私信目标用户 id（兼容 JSON 数字与 string）。
func PeerUserIDFromChatMessage(msg map[string]interface{}) (string, bool) {
	for _, key := range []string{"target_id", "to"} {
		if s, ok := stringifyJSONScalar(msg[key]); ok {
			return s, true
		}
	}
	return "", false
}
