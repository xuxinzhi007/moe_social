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

// WebSocket 升级器
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // 允许所有来源，生产环境应该限制
	},
}

// 全局用户连接映射
var (
	userConnections = make(map[string]*websocket.Conn)
	connectionsMutex sync.RWMutex
)

// 通知消息结构
type NotificationMessage struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

// 发送通知请求结构
type SendNotificationReq struct {
	UserID string      `json:"user_id"`
	Type   string      `json:"type"`
	Data   interface{} `json:"data"`
}

// 批量发送通知请求结构
type SendBatchNotificationReq struct {
	UserIDs []string   `json:"user_ids"`
	Type    string     `json:"type"`
	Data    interface{} `json:"data"`
}

// 广播通知请求结构
type BroadcastNotificationReq struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

type RemoteWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// WebSocket远程控制服务
func NewRemoteWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RemoteWsLogic {
	return &RemoteWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *RemoteWsLogic) RemoteWs() error {
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
		http.Error(*w, "Unauthorized", http.StatusUnauthorized)
		return nil
	}

	// 处理 Bearer token
	if strings.HasPrefix(token, "Bearer ") {
		token = strings.TrimPrefix(token, "Bearer ")
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
	connectionsMutex.Lock()
	userConnections[userID] = conn
	connectionsMutex.Unlock()
	l.Logger.Infof("User %s connected", userID)

	// 处理消息
	go l.handleConnection(userID, conn)

	return nil
}

// 处理 WebSocket 连接
func (l *RemoteWsLogic) handleConnection(userID string, conn *websocket.Conn) {
	defer func() {
		connectionsMutex.Lock()
		delete(userConnections, userID)
		connectionsMutex.Unlock()
		conn.Close()
		l.Logger.Infof("User %s disconnected", userID)
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
		l.Logger.Infof("Received message from %s: %s", userID, message)
		// 处理前端发送的消息
		l.handleMessage(userID, message)
	}
}

// 处理前端发送的消息
func (l *RemoteWsLogic) handleMessage(userID string, message []byte) {
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
	default:
		l.Logger.Infof("Unknown message type: %s", msgType)
	}
}

// 发送消息给指定用户
func (l *RemoteWsLogic) sendToUser(userID string, data interface{}) bool {
	connectionsMutex.RLock()
	conn, ok := userConnections[userID]
	connectionsMutex.RUnlock()

	if !ok {
		return false
	}

	message := NotificationMessage{
		Type: "notification",
		Data: data,
	}

	msgData, err := json.Marshal(message)
	if err != nil {
		l.Logger.Errorf("Error marshaling notification: %v", err)
		return false
	}

	err = conn.WriteMessage(websocket.TextMessage, msgData)
	if err != nil {
		l.Logger.Errorf("Error sending notification to %s: %v", userID, err)
		// 移除无效连接
		connectionsMutex.Lock()
		delete(userConnections, userID)
		connectionsMutex.Unlock()
		conn.Close()
		return false
	}

	return true
}

// 发送通知
func (l *RemoteWsLogic) SendNotification(req *SendNotificationReq) bool {
	return l.sendToUser(req.UserID, map[string]interface{}{
		"type": req.Type,
		"data": req.Data,
	})
}

// 批量发送通知
func (l *RemoteWsLogic) SendBatchNotification(req *SendBatchNotificationReq) int {
	successCount := 0
	for _, userID := range req.UserIDs {
		if l.sendToUser(userID, map[string]interface{}{
			"type": req.Type,
			"data": req.Data,
		}) {
			successCount++
		}
	}
	return successCount
}

// 广播通知
func (l *RemoteWsLogic) BroadcastNotification(req *BroadcastNotificationReq) int {
	successCount := 0
	connectionsMutex.RLock()
	for userID := range userConnections {
		connectionsMutex.RUnlock()
		if l.sendToUser(userID, map[string]interface{}{
			"type": req.Type,
			"data": req.Data,
		}) {
			successCount++
		}
		connectionsMutex.RLock()
	}
	connectionsMutex.RUnlock()
	return successCount
}