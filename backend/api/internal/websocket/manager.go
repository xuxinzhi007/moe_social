package websocket

import (
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/core/logx"
)

// ConnectionType 定义WebSocket连接类型
type ConnectionType string

const (
	// ConnectionTypeChat 聊天连接
	ConnectionTypeChat ConnectionType = "chat"
	// ConnectionTypePresence 在线状态连接
	ConnectionTypePresence ConnectionType = "presence"
	// ConnectionTypeWorld 世界聊天连接
	ConnectionTypeWorld ConnectionType = "world"
)

// Connection 表示一个WebSocket连接
type Connection struct {
	Conn      *websocket.Conn
	UserID    string
	Type      ConnectionType
	RoomID    string // 仅用于世界聊天
	CreatedAt time.Time
	LastPing  time.Time
	writeMu   sync.Mutex // 确保同一连接的写入操作是线程安全的
}

// Manager 管理所有WebSocket连接
type Manager struct {
	mu         sync.RWMutex
	connections map[string]map[*Connection]struct{} // userID -> connections
	roomConnections map[string]map[*Connection]struct{} // roomID -> connections (仅用于世界聊天)
}

// NewManager 创建一个新的连接管理器
func NewManager() *Manager {
	return &Manager{
		connections:     make(map[string]map[*Connection]struct{}),
		roomConnections: make(map[string]map[*Connection]struct{}),
	}
}

// DefaultManager 全局默认连接管理器
var DefaultManager = NewManager()

// AddConnection 添加一个新的WebSocket连接
func (m *Manager) AddConnection(userID string, conn *websocket.Conn, connType ConnectionType, roomID string) *Connection {
	m.mu.Lock()
	defer m.mu.Unlock()

	// 确保用户连接映射存在
	if _, ok := m.connections[userID]; !ok {
		m.connections[userID] = make(map[*Connection]struct{})
	}

	// 创建新的连接对象
	connection := &Connection{
		Conn:      conn,
		UserID:    userID,
		Type:      connType,
		RoomID:    roomID,
		CreatedAt: time.Now(),
		LastPing:  time.Now(),
	}

	// 添加到用户连接映射
	m.connections[userID][connection] = struct{}{}

	// 如果是世界聊天连接，添加到房间映射
	if connType == ConnectionTypeWorld && roomID != "" {
		if _, ok := m.roomConnections[roomID]; !ok {
			m.roomConnections[roomID] = make(map[*Connection]struct{})
		}
		m.roomConnections[roomID][connection] = struct{}{}
	}

	logx.Infof("Added new %s connection for user %s (room: %s)", connType, userID, roomID)
	return connection
}

// RemoveConnection 移除一个WebSocket连接
func (m *Manager) RemoveConnection(conn *Connection) {
	if conn == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	// 从用户连接映射中移除
	if userConns, ok := m.connections[conn.UserID]; ok {
		delete(userConns, conn)
		if len(userConns) == 0 {
			delete(m.connections, conn.UserID)
		}
	}

	// 如果是世界聊天连接，从房间映射中移除
	if conn.Type == ConnectionTypeWorld && conn.RoomID != "" {
		if roomConns, ok := m.roomConnections[conn.RoomID]; ok {
			delete(roomConns, conn)
			if len(roomConns) == 0 {
				delete(m.roomConnections, conn.RoomID)
			}
		}
	}

	// 关闭连接
	if conn.Conn != nil {
		conn.writeMu.Lock()
		conn.Conn.Close()
		conn.writeMu.Unlock()
	}

	logx.Infof("Removed %s connection for user %s (room: %s)", conn.Type, conn.UserID, conn.RoomID)
}

// GetUserConnections 获取用户的所有连接
func (m *Manager) GetUserConnections(userID string) []*Connection {
	m.mu.RLock()
	defer m.mu.RUnlock()

	connections := make([]*Connection, 0)
	if userConns, ok := m.connections[userID]; ok {
		for conn := range userConns {
			connections = append(connections, conn)
		}
	}

	return connections
}

// GetUserConnectionsByType 获取用户指定类型的连接
func (m *Manager) GetUserConnectionsByType(userID string, connType ConnectionType) []*Connection {
	m.mu.RLock()
	defer m.mu.RUnlock()

	connections := make([]*Connection, 0)
	if userConns, ok := m.connections[userID]; ok {
		for conn := range userConns {
			if conn.Type == connType {
				connections = append(connections, conn)
			}
		}
	}

	return connections
}

// GetRoomConnections 获取房间内的所有连接
func (m *Manager) GetRoomConnections(roomID string) []*Connection {
	m.mu.RLock()
	defer m.mu.RUnlock()

	connections := make([]*Connection, 0)
	if roomConns, ok := m.roomConnections[roomID]; ok {
		for conn := range roomConns {
			connections = append(connections, conn)
		}
	}

	return connections
}

// IsUserOnline 检查用户是否在线
func (m *Manager) IsUserOnline(userID string) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()

	conns, ok := m.connections[userID]
	return ok && len(conns) > 0
}

// GetOnlineUsers 获取所有在线用户ID
func (m *Manager) GetOnlineUsers() []string {
	m.mu.RLock()
	defer m.mu.RUnlock()

	userIDs := make([]string, 0, len(m.connections))
	for userID, conns := range m.connections {
		if len(conns) > 0 {
			userIDs = append(userIDs, userID)
		}
	}

	return userIDs
}

// UpdateLastPing 更新连接的最后活动时间
func (m *Manager) UpdateLastPing(conn *Connection) {
	if conn == nil {
		return
	}

	conn.LastPing = time.Now()
}

// CleanupInactiveConnections 清理不活跃的连接
func (m *Manager) CleanupInactiveConnections(maxInactiveTime time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()

	now := time.Now()
	inactiveThreshold := now.Add(-maxInactiveTime)

	for userID, userConns := range m.connections {
		for conn := range userConns {
			if conn.LastPing.Before(inactiveThreshold) {
				// 移除不活跃的连接
				delete(userConns, conn)

				// 如果是世界聊天连接，从房间映射中移除
				if conn.Type == ConnectionTypeWorld && conn.RoomID != "" {
					if roomConns, ok := m.roomConnections[conn.RoomID]; ok {
						delete(roomConns, conn)
						if len(roomConns) == 0 {
							delete(m.roomConnections, conn.RoomID)
						}
					}
				}

				// 关闭连接
				if conn.Conn != nil {
					conn.writeMu.Lock()
					conn.Conn.Close()
					conn.writeMu.Unlock()
				}

				logx.Infof("Cleaned up inactive %s connection for user %s", conn.Type, userID)
			}
		}

		// 如果用户没有连接了，移除用户映射
		if len(userConns) == 0 {
			delete(m.connections, userID)
		}
	}
}

// SendToUser 发送消息给指定用户
func (m *Manager) SendToUser(userID string, message []byte) int {
	connections := m.GetUserConnections(userID)
	sent := 0

	for _, conn := range connections {
		if conn.Conn != nil {
			conn.writeMu.Lock()
			err := conn.Conn.WriteMessage(websocket.TextMessage, message)
			conn.writeMu.Unlock()

			if err == nil {
				sent++
			} else {
				logx.Errorf("Error sending message to user %s: %v", userID, err)
				// 移除无效连接
				m.RemoveConnection(conn)
			}
		}
	}

	return sent
}

// SendToUserByType 发送消息给指定用户的指定类型连接
func (m *Manager) SendToUserByType(userID string, connType ConnectionType, message []byte) int {
	connections := m.GetUserConnectionsByType(userID, connType)
	sent := 0

	for _, conn := range connections {
		if conn.Conn != nil {
			conn.writeMu.Lock()
			err := conn.Conn.WriteMessage(websocket.TextMessage, message)
			conn.writeMu.Unlock()

			if err == nil {
				sent++
			} else {
				logx.Errorf("Error sending message to user %s: %v", userID, err)
				// 移除无效连接
				m.RemoveConnection(conn)
			}
		}
	}

	return sent
}

// BroadcastToRoom 广播消息到指定房间
func (m *Manager) BroadcastToRoom(roomID string, message []byte, excludeUserID string) int {
	connections := m.GetRoomConnections(roomID)
	sent := 0

	for _, conn := range connections {
		if conn.UserID != excludeUserID && conn.Conn != nil {
			conn.writeMu.Lock()
			err := conn.Conn.WriteMessage(websocket.TextMessage, message)
			conn.writeMu.Unlock()

			if err == nil {
				sent++
			} else {
				logx.Errorf("Error broadcasting message to room %s: %v", roomID, err)
				// 移除无效连接
				m.RemoveConnection(conn)
			}
		}
	}

	return sent
}

// BroadcastToAll 广播消息到所有连接
func (m *Manager) BroadcastToAll(message []byte, excludeUserID string) int {
	sent := 0

	m.mu.RLock()
	for userID, userConns := range m.connections {
		if userID == excludeUserID {
			continue
		}

		for conn := range userConns {
			if conn.Conn != nil {
				conn.writeMu.Lock()
				err := conn.Conn.WriteMessage(websocket.TextMessage, message)
				conn.writeMu.Unlock()

				if err == nil {
					sent++
				} else {
					logx.Errorf("Error broadcasting message to user %s: %v", userID, err)
					// 注意：这里不应该在RWMutex下修改映射
				}
			}
		}
	}
	m.mu.RUnlock()

	return sent
}

// GetConnectionCount 获取当前连接总数
func (m *Manager) GetConnectionCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	count := 0
	for _, userConns := range m.connections {
		count += len(userConns)
	}

	return count
}

// GetConnectionCountByType 获取指定类型的连接数
func (m *Manager) GetConnectionCountByType(connType ConnectionType) int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	count := 0
	for _, userConns := range m.connections {
		for conn := range userConns {
			if conn.Type == connType {
				count++
			}
		}
	}

	return count
}
