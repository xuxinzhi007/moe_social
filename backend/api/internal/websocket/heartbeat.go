package websocket

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/zeromicro/go-zero/core/logx"
)

// HeartbeatManager 心跳管理器
type HeartbeatManager struct {
	mu             sync.RWMutex
	heartbeatTicker *time.Ticker
	cleanupTicker  *time.Ticker
	connections    map[*Connection]bool
	closed         bool
}

// NewHeartbeatManager 创建一个新的心跳管理器
func NewHeartbeatManager() *HeartbeatManager {
	manager := &HeartbeatManager{
		connections:    make(map[*Connection]bool),
		heartbeatTicker: time.NewTicker(30 * time.Second),
		cleanupTicker:  time.NewTicker(60 * time.Second),
	}

	// 启动心跳协程
	go manager.heartbeatLoop()
	// 启动清理协程
	go manager.cleanupLoop()

	return manager
}

// DefaultHeartbeatManager 全局默认心跳管理器
var DefaultHeartbeatManager = NewHeartbeatManager()

// AddConnection 添加连接到心跳管理
func (hm *HeartbeatManager) AddConnection(conn *Connection) {
	if conn == nil {
		return
	}

	hm.mu.Lock()
	hm.connections[conn] = true
	hm.mu.Unlock()

	logx.Infof("Added connection to heartbeat manager for user %s", conn.UserID)
}

// RemoveConnection 从心跳管理中移除连接
func (hm *HeartbeatManager) RemoveConnection(conn *Connection) {
	if conn == nil {
		return
	}

	hm.mu.Lock()
	delete(hm.connections, conn)
	hm.mu.Unlock()

	logx.Infof("Removed connection from heartbeat manager for user %s", conn.UserID)
}

// heartbeatLoop 心跳循环
func (hm *HeartbeatManager) heartbeatLoop() {
	for {
		<-hm.heartbeatTicker.C
		hm.sendHeartbeats()
	}
}

// sendHeartbeats 发送心跳
func (hm *HeartbeatManager) sendHeartbeats() {
	hm.mu.RLock()
	connections := make([]*Connection, 0, len(hm.connections))
	for conn := range hm.connections {
		connections = append(connections, conn)
	}
	hm.mu.RUnlock()

	for _, conn := range connections {
		if conn != nil && conn.Conn != nil {
			hm.sendHeartbeat(conn)
		}
	}
}

// sendHeartbeat 发送心跳到单个连接
func (hm *HeartbeatManager) sendHeartbeat(conn *Connection) {
	// 创建心跳消息
	heartbeatMsg := Message{
		Type: "ping",
	}

	// 序列化消息
	msgData, err := json.Marshal(heartbeatMsg)
	if err != nil {
		logx.Errorf("Error marshaling heartbeat message: %v", err)
		return
	}

	// 发送心跳
	conn.writeMu.Lock()
	err = conn.Conn.WriteMessage(1, msgData) // 1 = TextMessage
	conn.writeMu.Unlock()

	if err != nil {
		logx.Errorf("Error sending heartbeat to user %s: %v", conn.UserID, err)
		// 移除无效连接
		DefaultManager.RemoveConnection(conn)
		hm.RemoveConnection(conn)
	}
}

// cleanupLoop 清理循环
func (hm *HeartbeatManager) cleanupLoop() {
	for {
		<-hm.cleanupTicker.C
		hm.cleanupInactiveConnections()
	}
}

// cleanupInactiveConnections 清理不活跃的连接
func (hm *HeartbeatManager) cleanupInactiveConnections() {
	// 调用连接管理器的清理方法
	DefaultManager.CleanupInactiveConnections(5 * time.Minute)

	// 同步心跳管理器中的连接
	hm.mu.Lock()
	for conn := range hm.connections {
		if conn == nil || conn.Conn == nil {
			delete(hm.connections, conn)
		}
	}
	hm.mu.Unlock()
}

// Close 关闭心跳管理器
func (hm *HeartbeatManager) Close() {
	hm.mu.Lock()
	if hm.closed {
		hm.mu.Unlock()
		return
	}
	hm.closed = true
	hm.mu.Unlock()

	// 停止定时器
	hm.heartbeatTicker.Stop()
	hm.cleanupTicker.Stop()

	// 清理连接
	hm.mu.Lock()
	for conn := range hm.connections {
		if conn != nil && conn.Conn != nil {
			conn.writeMu.Lock()
			conn.Conn.Close()
			conn.writeMu.Unlock()
		}
	}
	hm.connections = make(map[*Connection]bool)
	hm.mu.Unlock()

	logx.Info("Closed heartbeat manager")
}

// GetConnectionCount 获取当前管理的连接数
func (hm *HeartbeatManager) GetConnectionCount() int {
	hm.mu.RLock()
	defer hm.mu.RUnlock()

	return len(hm.connections)
}

// ReconnectManager 重连管理器
type ReconnectManager struct {
	mu             sync.RWMutex
	reconnectQueue map[string]*ReconnectInfo
	ticker         *time.Ticker
	closed         bool
}

// ReconnectInfo 重连信息
type ReconnectInfo struct {
	UserID      string
	ConnType    ConnectionType
	RoomID      string
	LastAttempt time.Time
	Attempts    int
	MaxAttempts int
	Backoff     time.Duration
}

// NewReconnectManager 创建一个新的重连管理器
func NewReconnectManager() *ReconnectManager {
	manager := &ReconnectManager{
		reconnectQueue: make(map[string]*ReconnectInfo),
		ticker:         time.NewTicker(10 * time.Second),
	}

	// 启动重连协程
	go manager.reconnectLoop()

	return manager
}

// DefaultReconnectManager 全局默认重连管理器
var DefaultReconnectManager = NewReconnectManager()

// AddReconnect 添加重连任务
func (rm *ReconnectManager) AddReconnect(userID string, connType ConnectionType, roomID string) {
	key := userID + ":" + string(connType) + ":" + roomID

	rm.mu.Lock()
	defer rm.mu.Unlock()

	// 检查是否已经存在重连任务
	if _, ok := rm.reconnectQueue[key]; ok {
		return
	}

	// 创建重连信息
	reconnectInfo := &ReconnectInfo{
		UserID:      userID,
		ConnType:    connType,
		RoomID:      roomID,
		LastAttempt: time.Now(),
		Attempts:    0,
		MaxAttempts: 5,
		Backoff:     5 * time.Second,
	}

	rm.reconnectQueue[key] = reconnectInfo
	logx.Infof("Added reconnect task for user %s, type %s, room %s", userID, connType, roomID)
}

// RemoveReconnect 移除重连任务
func (rm *ReconnectManager) RemoveReconnect(userID string, connType ConnectionType, roomID string) {
	key := userID + ":" + string(connType) + ":" + roomID

	rm.mu.Lock()
	if _, ok := rm.reconnectQueue[key]; ok {
		delete(rm.reconnectQueue, key)
		logx.Infof("Removed reconnect task for user %s, type %s, room %s", userID, connType, roomID)
	}
	rm.mu.Unlock()
}

// reconnectLoop 重连循环
func (rm *ReconnectManager) reconnectLoop() {
	for {
		<-rm.ticker.C
		rm.attemptReconnects()
	}
}

// attemptReconnects 尝试重连
func (rm *ReconnectManager) attemptReconnects() {
	rm.mu.RLock()
	reconnects := make([]*ReconnectInfo, 0, len(rm.reconnectQueue))
	for _, info := range rm.reconnectQueue {
		reconnects = append(reconnects, info)
	}
	rm.mu.RUnlock()

	for _, info := range reconnects {
		// 检查是否达到最大尝试次数
		if info.Attempts >= info.MaxAttempts {
			rm.RemoveReconnect(info.UserID, info.ConnType, info.RoomID)
			logx.Infof("Max reconnect attempts reached for user %s, type %s, room %s", info.UserID, info.ConnType, info.RoomID)
			continue
		}

		// 检查是否到达重连时间
		if time.Since(info.LastAttempt) < info.Backoff {
			continue
		}

		// 尝试重连（这里只是模拟，实际重连需要前端发起）
		rm.attemptReconnect(info)
	}
}

// attemptReconnect 尝试单个重连
func (rm *ReconnectManager) attemptReconnect(info *ReconnectInfo) {
	// 更新重连信息
	info.LastAttempt = time.Now()
	info.Attempts++
	info.Backoff *= 2 // 指数退避

	// 这里可以发送重连通知给前端，或者实现服务器端的重连逻辑
	// 由于WebSocket是客户端发起的，服务器端无法主动建立连接
	// 所以这里主要是记录重连尝试，并可以通过其他渠道通知客户端

	logx.Infof("Attempting to reconnect user %s, type %s, room %s (attempt %d/%d)", 
		info.UserID, info.ConnType, info.RoomID, info.Attempts, info.MaxAttempts)

	// 检查用户是否已经重新连接
	if DefaultManager.IsUserOnline(info.UserID) {
		rm.RemoveReconnect(info.UserID, info.ConnType, info.RoomID)
		logx.Infof("User %s already reconnected, removing reconnect task", info.UserID)
	}
}

// Close 关闭重连管理器
func (rm *ReconnectManager) Close() {
	rm.mu.Lock()
	if rm.closed {
		rm.mu.Unlock()
		return
	}
	rm.closed = true
	rm.mu.Unlock()

	// 停止定时器
	rm.ticker.Stop()

	// 清空重连队列
	rm.mu.Lock()
	rm.reconnectQueue = make(map[string]*ReconnectInfo)
	rm.mu.Unlock()

	logx.Info("Closed reconnect manager")
}

// GetReconnectCount 获取当前重连任务数
func (rm *ReconnectManager) GetReconnectCount() int {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	return len(rm.reconnectQueue)
}
