package websocket

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

// TestConnectionManager 测试连接管理器
func TestConnectionManager(t *testing.T) {
	// 创建一个测试服务器
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 升级为WebSocket连接
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Errorf("Failed to upgrade connection: %v", err)
			return
		}
		defer conn.Close()

		// 添加连接到管理器
		userID := "test_user"
		connection := DefaultManager.AddConnection(userID, conn, ConnectionTypeChat, "")

		// 测试发送消息
		message := []byte(`{"type":"ping"}`)
		DefaultManager.SendToUser(userID, message)

		// 读取消息
		_, msg, err := conn.ReadMessage()
		if err != nil {
			t.Errorf("Failed to read message: %v", err)
			return
		}

		// 验证消息
		var response map[string]interface{}
		if err := json.Unmarshal(msg, &response); err != nil {
			t.Errorf("Failed to unmarshal message: %v", err)
			return
		}

		if response["type"] != "pong" {
			t.Errorf("Expected pong message, got %v", response["type"])
		}

		// 移除连接
		DefaultManager.RemoveConnection(connection)
	}))
	defer server.Close()

	// 连接到测试服务器
	wsURL := strings.Replace(server.URL, "http", "ws", 1)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Errorf("Failed to dial server: %v", err)
		return
	}
	defer conn.Close()

	// 发送ping消息
	message := []byte(`{"type":"ping"}`)
	if err := conn.WriteMessage(websocket.TextMessage, message); err != nil {
		t.Errorf("Failed to send message: %v", err)
		return
	}

	// 读取pong消息
	_, msg, err := conn.ReadMessage()
	if err != nil {
		t.Errorf("Failed to read message: %v", err)
		return
	}

	// 验证消息
	var response map[string]interface{}
	if err := json.Unmarshal(msg, &response); err != nil {
		t.Errorf("Failed to unmarshal message: %v", err)
		return
	}

	if response["type"] != "pong" {
		t.Errorf("Expected pong message, got %v", response["type"])
	}
}

// TestMessageRouter 测试消息路由器
func TestMessageRouter(t *testing.T) {
	// 注册默认处理器
	DefaultRouter.RegisterDefaultHandlers()

	// 创建一个测试连接
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 升级为WebSocket连接
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Errorf("Failed to upgrade connection: %v", err)
			return
		}
		defer conn.Close()

		// 添加连接到管理器
		userID := "test_user"
		connection := DefaultManager.AddConnection(userID, conn, ConnectionTypeChat, "")

		// 处理消息
		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				break
			}

			// 路由消息
			DefaultRouter.HandleMessage(connection, message)
		}

		// 移除连接
		DefaultManager.RemoveConnection(connection)
	}))
	defer server.Close()

	// 连接到测试服务器
	wsURL := strings.Replace(server.URL, "http", "ws", 1)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Errorf("Failed to dial server: %v", err)
		return
	}
	defer conn.Close()

	// 发送ping消息
	message := []byte(`{"type":"ping"}`)
	if err := conn.WriteMessage(websocket.TextMessage, message); err != nil {
		t.Errorf("Failed to send message: %v", err)
		return
	}

	// 读取pong消息
	_, msg, err := conn.ReadMessage()
	if err != nil {
		t.Errorf("Failed to read message: %v", err)
		return
	}

	// 验证消息
	var response map[string]interface{}
	if err := json.Unmarshal(msg, &response); err != nil {
		t.Errorf("Failed to unmarshal message: %v", err)
		return
	}

	if response["type"] != "pong" {
		t.Errorf("Expected pong message, got %v", response["type"])
	}
}

// TestSessionManager 测试会话管理器
func TestSessionManager(t *testing.T) {
	// 创建会话
	sessionID := "test_session"
	userID := "test_user"
	session := DefaultSessionManager.CreateSession(sessionID, userID)

	// 验证会话
	if session.SessionID != sessionID {
		t.Errorf("Expected session ID %s, got %s", sessionID, session.SessionID)
	}

	if session.UserID != userID {
		t.Errorf("Expected user ID %s, got %s", userID, session.UserID)
	}

	// 设置会话数据
	session.SetSessionData("key", "value")

	// 获取会话数据
	value := session.GetSessionData("key")
	if value != "value" {
		t.Errorf("Expected value 'value', got %v", value)
	}

	// 获取会话
	retrievedSession := DefaultSessionManager.GetSession(sessionID)
	if retrievedSession == nil {
		t.Errorf("Failed to retrieve session")
		return
	}

	// 验证会话数据
	retrievedValue := retrievedSession.GetSessionData("key")
	if retrievedValue != "value" {
		t.Errorf("Expected value 'value', got %v", retrievedValue)
	}

	// 移除会话
	DefaultSessionManager.RemoveSession(sessionID)

	// 验证会话已移除
	removedSession := DefaultSessionManager.GetSession(sessionID)
	if removedSession != nil {
		t.Errorf("Expected session to be removed")
	}
}

// TestRateLimiter 测试速率限制器
func TestRateLimiter(t *testing.T) {
	// 测试允许请求
	userID := "test_user"
	allowed := DefaultRateLimiter.Allow(userID)
	if !allowed {
		t.Errorf("Expected request to be allowed")
	}

	// 测试速率限制
	for i := 0; i < 100; i++ {
		DefaultRateLimiter.Allow(userID)
	}

	// 应该被限制
	allowed = DefaultRateLimiter.Allow(userID)
	if allowed {
		t.Errorf("Expected request to be rate limited")
	}

	// 重置速率限制
	DefaultRateLimiter.Reset(userID)

	// 应该再次允许
	allowed = DefaultRateLimiter.Allow(userID)
	if !allowed {
		t.Errorf("Expected request to be allowed after reset")
	}
}

// TestConnectionLimiter 测试连接限制器
func TestConnectionLimiter(t *testing.T) {
	// 测试允许连接
	userID := "test_user"
	allowed := DefaultConnectionLimiter.Allow(userID)
	if !allowed {
		t.Errorf("Expected connection to be allowed")
	}

	// 释放连接
	DefaultConnectionLimiter.Release(userID)

	// 验证连接已释放
	count := DefaultConnectionLimiter.GetUserConnectionCount(userID)
	if count != 0 {
		t.Errorf("Expected connection count to be 0, got %d", count)
	}
}

// TestBroadcastManager 测试广播管理器
func TestBroadcastManager(t *testing.T) {
	// 创建测试连接
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 升级为WebSocket连接
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Errorf("Failed to upgrade connection: %v", err)
			return
		}
		defer conn.Close()

		// 添加连接到管理器
		userID := "test_user"
		connection := DefaultManager.AddConnection(userID, conn, ConnectionTypeChat, "test_room")

		// 处理消息
		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				break
			}
		}

		// 移除连接
		DefaultManager.RemoveConnection(connection)
	}))
	defer server.Close()

	// 连接到测试服务器
	wsURL := strings.Replace(server.URL, "http", "ws", 1)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Errorf("Failed to dial server: %v", err)
		return
	}
	defer conn.Close()

	// 等待连接建立
	time.Sleep(100 * time.Millisecond)

	// 广播消息
	message := []byte(`{"type":"test","content":"test message"}`)
	sent := DefaultBroadcastManager.BroadcastToRoom("test_room", message, "")
	if sent == 0 {
		t.Errorf("Expected at least one message to be sent")
	}
}

// TestHeartbeatManager 测试心跳管理器
func TestHeartbeatManager(t *testing.T) {
	// 创建测试连接
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 升级为WebSocket连接
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Errorf("Failed to upgrade connection: %v", err)
			return
		}
		defer conn.Close()

		// 添加连接到管理器
		userID := "test_user"
		connection := DefaultManager.AddConnection(userID, conn, ConnectionTypeChat, "")

		// 添加到心跳管理器
		DefaultHeartbeatManager.AddConnection(connection)

		// 处理消息
		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				break
			}

			// 路由消息
			DefaultRouter.HandleMessage(connection, message)
		}

		// 移除连接
		DefaultManager.RemoveConnection(connection)
		DefaultHeartbeatManager.RemoveConnection(connection)
	}))
	defer server.Close()

	// 连接到测试服务器
	wsURL := strings.Replace(server.URL, "http", "ws", 1)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Errorf("Failed to dial server: %v", err)
		return
	}
	defer conn.Close()

	// 等待心跳
	time.Sleep(2 * time.Second)

	// 验证连接仍然存在
	userID := "test_user"
	connections := DefaultManager.GetUserConnections(userID)
	if len(connections) == 0 {
		t.Errorf("Expected at least one connection")
	}
}

// TestMessageQueue 测试消息队列
func TestMessageQueue(t *testing.T) {
	// 创建测试消息
	message := &QueuedMessage{
		Message:    []byte(`{"type":"test","content":"test message"}`),
		UserID:     "test_user",
		ConnType:   ConnectionTypeChat,
		RoomID:     "",
		Timestamp:  time.Now(),
		Retries:    0,
		MaxRetries: 3,
	}

	// 入队消息
	DefaultMessageQueue.Enqueue(message)

	// 验证队列大小
	size := DefaultMessageQueue.Size()
	if size == 0 {
		t.Errorf("Expected queue size to be at least 1")
	}
}

// TestErrorManager 测试错误管理器
func TestErrorManager(t *testing.T) {
	// 创建测试错误
	err := NewWebSocketError(ErrorTypeConnection, "Test error", nil)

	// 处理错误
	DefaultErrorManager.HandleError(err, nil)

	// 验证错误计数
	count := DefaultErrorManager.GetErrorCount(ErrorTypeConnection)
	if count == 0 {
		t.Errorf("Expected error count to be at least 1")
	}

	// 重置错误计数
	DefaultErrorManager.ResetErrorCounts()

	// 验证错误计数已重置
	count = DefaultErrorManager.GetErrorCount(ErrorTypeConnection)
	if count != 0 {
		t.Errorf("Expected error count to be 0 after reset")
	}
}
