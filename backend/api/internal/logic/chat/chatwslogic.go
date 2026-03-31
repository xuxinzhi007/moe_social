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

// 全局聊天连接映射
var (
	chatConnections      = make(map[string]*websocket.Conn)
	chatConnectionsMutex sync.RWMutex
)

// 聊天消息结构
type ChatMessage struct {
	From    string `json:"from"`
	Content string `json:"content"`
	Time    string `json:"time"`
}

type ChatWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// WebSocket聊天服务
func NewChatWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatWsLogic {
	return &ChatWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatWsLogic) ChatWs() error {
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
	chatConnectionsMutex.Lock()
	chatConnections[userID] = conn
	chatConnectionsMutex.Unlock()
	l.Logger.Infof("Chat user %s connected", userID)

	// 处理消息
	go l.handleConnection(userID, conn)

	return nil
}

// 处理 WebSocket 连接
func (l *ChatWsLogic) handleConnection(userID string, conn *websocket.Conn) {
	defer func() {
		TryMatchCancel(userID)
		chatConnectionsMutex.Lock()
		delete(chatConnections, userID)
		chatConnectionsMutex.Unlock()
		conn.Close()
		l.Logger.Infof("Chat user %s disconnected", userID)
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
		l.Logger.Infof("Received chat message from %s: %s", userID, message)
		// 处理前端发送的消息
		l.handleMessage(userID, message)
	}
}

// 处理前端发送的消息
func (l *ChatWsLogic) handleMessage(userID string, message []byte) {
	// 解析消息
	var msg map[string]interface{}
	if err := json.Unmarshal(message, &msg); err != nil {
		l.Logger.Errorf("Error unmarshaling message: %v", err)
		return
	}

	// 打印完整消息，用于调试
	l.Logger.Infof("Received full message from %s: %v", userID, msg)

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
	case "match_join":
		TryMatchJoin(userID, l.sendToUser)
	case "match_cancel":
		TryMatchCancel(userID)
		l.sendToUser(userID, map[string]interface{}{
			"type": "match_cancelled",
		})
	case "message":
		// 处理聊天消息
		l.handleChatMessage(userID, msg)
	default:
		l.Logger.Infof("Unknown message type: %s", msgType)
	}
}

// 处理聊天消息
func (l *ChatWsLogic) handleChatMessage(userID string, msg map[string]interface{}) {
	// 提取消息内容
	content, ok := msg["content"].(string)
	if !ok {
		l.Logger.Errorf("Invalid message content")
		return
	}

	// 支持 both "target_id" and "to" fields
	targetID, ok := msg["target_id"].(string)
	if !ok {
		// 尝试从 "to" 字段获取
		targetID, ok = msg["to"].(string)
		if !ok {
			l.Logger.Errorf("Invalid target ID: neither 'target_id' nor 'to' field found")
			return
		}
	}

	// 尝试获取发送者信息，支持多种字段名
	senderName := "用户"
	senderAvatar := ""

	// 尝试从不同字段名获取发送者名称
	if name, ok := msg["sender_name"].(string); ok && name != "" {
		senderName = name
	} else if name, ok := msg["senderName"].(string); ok && name != "" {
		senderName = name
	}

	// 尝试从不同字段名获取发送者头像
	if avatar, ok := msg["sender_avatar"].(string); ok && avatar != "" {
		senderAvatar = avatar
	} else if avatar, ok := msg["senderAvatar"].(string); ok && avatar != "" {
		senderAvatar = avatar
	}

	// 打印发送者信息，用于调试
	l.Logger.Infof("Sending message from %s to %s: senderName=%s, senderAvatar=%s", userID, targetID, senderName, senderAvatar)

	// 创建聊天消息
	chatMsg := map[string]interface{}{
		"from":          userID,
		"content":       content,
		"time":          time.Now().Format(time.RFC3339),
		"sender_name":   senderName,
		"sender_avatar": senderAvatar,
		"senderName":    senderName,   // 同时添加驼峰命名的字段，确保前端兼容
		"senderAvatar":  senderAvatar, // 同时添加驼峰命名的字段，确保前端兼容
	}

	// 发送消息给目标用户
	l.sendToUser(targetID, chatMsg)
}

// 发送消息给指定用户
func (l *ChatWsLogic) sendToUser(userID string, data interface{}) bool {
	chatConnectionsMutex.RLock()
	conn, ok := chatConnections[userID]
	chatConnectionsMutex.RUnlock()

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
		chatConnectionsMutex.Lock()
		delete(chatConnections, userID)
		chatConnectionsMutex.Unlock()
		conn.Close()
		return false
	}

	return true
}
