package websocket

import (
	"errors"
	"sync"
	"time"

	"github.com/zeromicro/go-zero/core/logx"
)

var errConnectionPoolClosed = errors.New("connection pool is closed")

// ConnectionPool 连接池接口
type ConnectionPool interface {
	Get() (*Connection, error)
	Put(conn *Connection)
	Close()
	Size() int
}

// SimpleConnectionPool 简单连接池实现
type SimpleConnectionPool struct {
	mu         sync.RWMutex
	connections chan *Connection
	closed      bool
	size        int
	connType    ConnectionType
	userID      string
	roomID      string
}

// NewConnectionPool 创建一个新的连接池
func NewConnectionPool(size int, connType ConnectionType, userID, roomID string) *SimpleConnectionPool {
	pool := &SimpleConnectionPool{
		connections: make(chan *Connection, size),
		size:        size,
		connType:    connType,
		userID:      userID,
		roomID:      roomID,
	}

	// 预热连接池
	// 注意：这里只是创建连接池结构，实际的WebSocket连接需要在使用时创建

	return pool
}

// Get 从连接池获取一个连接
func (p *SimpleConnectionPool) Get() (*Connection, error) {
	p.mu.RLock()
	if p.closed {
		p.mu.RUnlock()
		return nil, errConnectionPoolClosed
	}
	p.mu.RUnlock()

	select {
	case conn, ok := <-p.connections:
		if !ok {
			return nil, errConnectionPoolClosed
		}
		// 检查连接是否有效
		if conn != nil && conn.Conn != nil {
			// 更新连接的最后活动时间
			DefaultManager.UpdateLastPing(conn)
			logx.Infof("Retrieved connection from pool for user %s", p.userID)
			return conn, nil
		}
		// 连接无效，创建新连接
		return nil, nil
	default:
		// 连接池为空，返回nil，让调用者创建新连接
		return nil, nil
	}
}

// Put 将连接放回连接池
func (p *SimpleConnectionPool) Put(conn *Connection) {
	if conn == nil || conn.Conn == nil {
		return
	}

	p.mu.Lock()
	if p.closed {
		p.mu.Unlock()
		// 连接池已关闭，关闭连接
		conn.writeMu.Lock()
		conn.Conn.Close()
		conn.writeMu.Unlock()
		return
	}

	select {
	case p.connections <- conn:
		// 连接成功放回连接池
		logx.Infof("Returned connection to pool for user %s", p.userID)
	default:
		// 连接池已满，关闭连接
		logx.Infof("Connection pool full, closing connection for user %s", p.userID)
		conn.writeMu.Lock()
		conn.Conn.Close()
		conn.writeMu.Unlock()
	}
	p.mu.Unlock()
}

// Close 关闭连接池
func (p *SimpleConnectionPool) Close() {
	p.mu.Lock()
	if p.closed {
		p.mu.Unlock()
		return
	}
	p.closed = true
	p.mu.Unlock()

	// 关闭所有连接
	close(p.connections)
	for conn := range p.connections {
		if conn != nil && conn.Conn != nil {
			conn.writeMu.Lock()
			conn.Conn.Close()
			conn.writeMu.Unlock()
		}
	}

	logx.Infof("Closed connection pool for user %s", p.userID)
}

// Size 获取连接池大小
func (p *SimpleConnectionPool) Size() int {
	p.mu.RLock()
	defer p.mu.RUnlock()

	return len(p.connections)
}

// ConnectionPoolManager 连接池管理器
type ConnectionPoolManager struct {
	mu    sync.RWMutex
	pools map[string]*SimpleConnectionPool
}

// NewConnectionPoolManager 创建一个新的连接池管理器
func NewConnectionPoolManager() *ConnectionPoolManager {
	return &ConnectionPoolManager{
		pools: make(map[string]*SimpleConnectionPool),
	}
}

// DefaultConnectionPoolManager 全局默认连接池管理器
var DefaultConnectionPoolManager = NewConnectionPoolManager()

// GetPool 获取或创建用户的连接池
func (pm *ConnectionPoolManager) GetPool(userID string, connType ConnectionType, roomID string) *SimpleConnectionPool {
	key := userID + ":" + string(connType) + ":" + roomID

	pm.mu.RLock()
	pool, ok := pm.pools[key]
	pm.mu.RUnlock()

	if !ok {
		pm.mu.Lock()
		// 再次检查，避免并发创建
		if pool, ok = pm.pools[key]; !ok {
			// 创建新的连接池，默认大小为5
			pool = NewConnectionPool(5, connType, userID, roomID)
			pm.pools[key] = pool
			logx.Infof("Created new connection pool for user %s, type %s, room %s", userID, connType, roomID)
		}
		pm.mu.Unlock()
	}

	return pool
}

// RemovePool 移除用户的连接池
func (pm *ConnectionPoolManager) RemovePool(userID string, connType ConnectionType, roomID string) {
	key := userID + ":" + string(connType) + ":" + roomID

	pm.mu.Lock()
	if pool, ok := pm.pools[key]; ok {
		pool.Close()
		delete(pm.pools, key)
		logx.Infof("Removed connection pool for user %s, type %s, room %s", userID, connType, roomID)
	}
	pm.mu.Unlock()
}

// CleanupInactivePools 清理不活跃的连接池
func (pm *ConnectionPoolManager) CleanupInactivePools(maxInactiveTime time.Duration) {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	// now := time.Now()
	// inactiveThreshold := now.Add(-maxInactiveTime)
	removed := 0

	for key, pool := range pm.pools {
		// 检查连接池是否不活跃（这里简化处理，实际应该检查连接池的最后活动时间）
		if pool.Size() == 0 {
			pool.Close()
			delete(pm.pools, key)
			removed++
		}
	}

	if removed > 0 {
		logx.Infof("Cleaned up %d inactive connection pools", removed)
	}
}

// GetPoolCount 获取连接池总数
func (pm *ConnectionPoolManager) GetPoolCount() int {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	return len(pm.pools)
}
