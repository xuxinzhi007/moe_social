package websocket

import (
	"encoding/json"
	"sync"

	"github.com/zeromicro/go-zero/core/logx"
)

// Message 定义WebSocket消息结构
type Message struct {
	Type    string      `json:"type"`
	Content interface{} `json:"content,omitempty"`
	From    string      `json:"from,omitempty"`
	To      string      `json:"to,omitempty"`
	RoomID  string      `json:"room_id,omitempty"`
}

// Handler 定义消息处理函数类型
type Handler func(conn *Connection, message *Message)

// Router 消息路由器
type Router struct {
	mu       sync.RWMutex
	handlers map[string]Handler
}

// NewRouter 创建一个新的消息路由器
func NewRouter() *Router {
	return &Router{
		handlers: make(map[string]Handler),
	}
}

// DefaultRouter 全局默认消息路由器
var DefaultRouter = NewRouter()

// RegisterHandler 注册消息处理函数
func (r *Router) RegisterHandler(messageType string, handler Handler) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.handlers[messageType] = handler
	logx.Infof("Registered handler for message type: %s", messageType)
}

// UnregisterHandler 取消注册消息处理函数
func (r *Router) UnregisterHandler(messageType string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	delete(r.handlers, messageType)
	logx.Infof("Unregistered handler for message type: %s", messageType)
}

// HandleMessage 处理消息
func (r *Router) HandleMessage(conn *Connection, rawMessage []byte) error {
	// 解析消息
	var message Message
	if err := json.Unmarshal(rawMessage, &message); err != nil {
		logx.Errorf("Error unmarshaling message: %v", err)
		return err
	}

	// 更新连接的最后活动时间
	DefaultManager.UpdateLastPing(conn)

	// 获取消息类型
	messageType := message.Type
	if messageType == "" {
		logx.Errorf("Empty message type")
		return nil
	}

	// 查找对应的处理函数
	r.mu.RLock()
	handler, ok := r.handlers[messageType]
	r.mu.RUnlock()

	if !ok {
		logx.Infof("No handler for message type: %s", messageType)
		return nil
	}

	// 调用处理函数
	handler(conn, &message)
	return nil
}

// RegisterDefaultHandlers 注册默认的消息处理函数
func (r *Router) RegisterDefaultHandlers() {
	// 注册ping消息处理
	r.RegisterHandler("ping", func(conn *Connection, message *Message) {
		// 响应pong
		response := Message{
			Type: "pong",
		}
		responseData, _ := json.Marshal(response)
		conn.writeMu.Lock()
		conn.Conn.WriteMessage(1, responseData) // 1 = TextMessage
		conn.writeMu.Unlock()
	})

	// 注册聊天消息处理
	r.RegisterHandler("message", func(conn *Connection, message *Message) {
		// 转发消息给目标用户
		if message.To != "" {
			responseData, _ := json.Marshal(message)
			DefaultManager.SendToUser(message.To, responseData)
		}
	})

	// 注册世界聊天消息处理
	r.RegisterHandler("world_move", func(conn *Connection, message *Message) {
		// 广播位置更新到房间
		if conn.RoomID != "" {
			responseData, _ := json.Marshal(message)
			DefaultManager.BroadcastToRoom(conn.RoomID, responseData, conn.UserID)
		}
	})

	// 注册世界聊天用户加入处理
	r.RegisterHandler("world_peer_joined", func(conn *Connection, message *Message) {
		// 广播用户加入到房间
		if conn.RoomID != "" {
			responseData, _ := json.Marshal(message)
			DefaultManager.BroadcastToRoom(conn.RoomID, responseData, conn.UserID)
		}
	})

	// 注册世界聊天用户离开处理
	r.RegisterHandler("world_peer_left", func(conn *Connection, message *Message) {
		// 广播用户离开到房间
		if conn.RoomID != "" {
			responseData, _ := json.Marshal(message)
			DefaultManager.BroadcastToRoom(conn.RoomID, responseData, conn.UserID)
		}
	})

	// 注册世界聊天用户资料更新处理
	r.RegisterHandler("world_peer_profile", func(conn *Connection, message *Message) {
		// 广播用户资料更新到房间
		if conn.RoomID != "" {
			responseData, _ := json.Marshal(message)
			DefaultManager.BroadcastToRoom(conn.RoomID, responseData, conn.UserID)
		}
	})

	// 注册在线状态请求处理
	r.RegisterHandler("get_online", func(conn *Connection, message *Message) {
		// 发送在线用户列表
		onlineUsers := DefaultManager.GetOnlineUsers()
		response := Message{
			Type:    "presence_snapshot",
			Content: map[string]interface{}{
				"online_user_ids": onlineUsers,
			},
		}
		responseData, _ := json.Marshal(response)
		conn.writeMu.Lock()
		conn.Conn.WriteMessage(1, responseData) // 1 = TextMessage
		conn.writeMu.Unlock()
	})

	logx.Info("Registered default message handlers")
}
