package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"backend/api/internal/svc"
	"backend/utils"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/core/logx"
)

// 全局在线状态连接映射
var (
	presenceConnections = make(map[string]*websocket.Conn)
	presenceConnectionsMutex sync.RWMutex
	onlineUsers = make(map[string]bool)
	onlineUsersMutex sync.RWMutex
)

// 在线状态消息结构
type PresenceMessage struct {
	Type       string   `json:"type"`
	UserID     string   `json:"user_id,omitempty"`
	Online     bool     `json:"online,omitempty"`
	OnlineUserIDs []string `json:"online_user_ids,omitempty"`
}

type PresenceWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// WebSocket在线状态服务
func NewPresenceWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *PresenceWsLogic {
	return &PresenceWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *PresenceWsLogic) PresenceWs() error {
	// 从上下文获取 HTTP 请求
	r, ok := l.ctx.Value("http.Request").(*http.Request)
	if !ok {
		return nil
	}

	w, ok := l.ctx.Value("http.ResponseWriter").(*http.ResponseWriter)
	if !ok {
		return nil
	}

	// 验证 token
	token := r.Header.Get("Authorization")
	if token == "" {
		// 尝试从查询参数获取 token
		token = r.URL.Query().Get("token")
		if token == "" {
			http.Error(*w, "Unauthorized", http.StatusUnauthorized)
			return nil
		}
	} else {
		// 处理 Bearer token
		if strings.HasPrefix(token, "Bearer ") {
			token = strings.TrimPrefix(token, "Bearer ")
		}
	}

	// 验证 token
	claims, err := utils.ParseToken(token)
	if err != nil {
		http.Error(*w, "Invalid token", http.StatusUnauthorized)
		return nil
	}

	// 获取用户 ID
	userID := fmt.Sprintf("%d", claims.UserID)

	// 升级 HTTP 连接为 WebSocket
	conn, err := upgrader.Upgrade(*w, r, nil)
	if err != nil {
		l.Logger.Errorf("Error upgrading connection: %v", err)
		return nil
	}

	// 存储用户连接
	presenceConnectionsMutex.Lock()
	presenceConnections[userID] = conn
	presenceConnectionsMutex.Unlock()

	// 更新在线状态
	onlineUsersMutex.Lock()
	onlineUsers[userID] = true
	onlineUsersMutex.Unlock()

	l.Logger.Infof("Presence user %s connected", userID)

	// 发送在线状态快照
	l.sendPresenceSnapshot(userID)

	// 广播用户上线通知
	l.broadcastPresence(userID, true)

	// 处理消息
	go l.handleConnection(userID, conn)

	return nil
}

// 处理 WebSocket 连接
func (l *PresenceWsLogic) handleConnection(userID string, conn *websocket.Conn) {
	defer func() {
		presenceConnectionsMutex.Lock()
		delete(presenceConnections, userID)
		presenceConnectionsMutex.Unlock()

		// 更新在线状态
		onlineUsersMutex.Lock()
		delete(onlineUsers, userID)
		onlineUsersMutex.Unlock()

		conn.Close()
		l.Logger.Infof("Presence user %s disconnected", userID)

		// 广播用户下线通知
		l.broadcastPresence(userID, false)
	}()

	// 设置读取超时
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				l.Logger.Errorf("WebSocket error: %v", err)
			}
			break
		}
		l.Logger.Infof("Received presence message from %s: %s", userID, message)
		// 处理前端发送的消息
		l.handleMessage(userID, message)
	}
}

// 处理前端发送的消息
func (l *PresenceWsLogic) handleMessage(userID string, message []byte) {
	// 解析消息
	var msg map[string]interface{}
	if err := json.Unmarshal(message, &msg); err != nil {
		l.Logger.Errorf("Error unmarshaling message: %v", err)
		return
	}

	// 根据消息类型处理
	msgType, ok := msg["type"].(string)
	if !ok {
		l.Logger.Errorf("Invalid message type")
		return
	}

	switch msgType {
	case "ping":
		// 响应 ping
		l.sendToUser(userID, map[string]interface{}{
			"type": "pong",
		})
	case "get_online":
		// 发送在线状态快照
		l.sendPresenceSnapshot(userID)
	default:
		l.Logger.Infof("Unknown message type: %s", msgType)
	}
}

// 发送在线状态快照
func (l *PresenceWsLogic) sendPresenceSnapshot(userID string) {
	onlineUsersMutex.RLock()
	userIDs := make([]string, 0, len(onlineUsers))
	for id := range onlineUsers {
		userIDs = append(userIDs, id)
	}
	onlineUsersMutex.RUnlock()

	message := PresenceMessage{
		Type:       "presence_snapshot",
		OnlineUserIDs: userIDs,
	}

	l.sendToUser(userID, message)
}

// 广播用户在线状态变化
func (l *PresenceWsLogic) broadcastPresence(userID string, online bool) {
	message := PresenceMessage{
		Type:   "presence",
		UserID: userID,
		Online: online,
	}

	presenceConnectionsMutex.RLock()
	for id, conn := range presenceConnections {
		if id == userID {
			continue
		}

		msgData, err := json.Marshal(message)
		if err != nil {
			l.Logger.Errorf("Error marshaling presence message: %v", err)
			continue
		}

		err = conn.WriteMessage(websocket.TextMessage, msgData)
		if err != nil {
			l.Logger.Errorf("Error sending presence message to %s: %v", id, err)
			// 移除无效连接
			presenceConnectionsMutex.RUnlock()
			presenceConnectionsMutex.Lock()
			delete(presenceConnections, id)
			presenceConnectionsMutex.Unlock()
			presenceConnectionsMutex.RLock()
		}
	}
	presenceConnectionsMutex.RUnlock()
}

// 发送消息给指定用户
func (l *PresenceWsLogic) sendToUser(userID string, data interface{}) bool {
	presenceConnectionsMutex.RLock()
	conn, ok := presenceConnections[userID]
	presenceConnectionsMutex.RUnlock()

	if !ok {
		return false
	}

	msgData, err := json.Marshal(data)
	if err != nil {
		l.Logger.Errorf("Error marshaling message: %v", err)
		return false
	}

	err = conn.WriteMessage(websocket.TextMessage, msgData)
	if err != nil {
		l.Logger.Errorf("Error sending message to %s: %v", userID, err)
		// 移除无效连接
		presenceConnectionsMutex.Lock()
		delete(presenceConnections, userID)
		presenceConnectionsMutex.Unlock()
		conn.Close()
		return false
	}

	return true
}

// 获取在线用户列表
func (l *PresenceWsLogic) GetOnlineUsers() map[string]bool {
	onlineUsersMutex.RLock()
	defer onlineUsersMutex.RUnlock()

	result := make(map[string]bool)
	for id, online := range onlineUsers {
		result[id] = online
	}

	return result
}
