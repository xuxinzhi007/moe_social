package websocket

import (
	"sync"

	"github.com/zeromicro/go-zero/core/logx"
)

// BroadcastManager 广播管理器
type BroadcastManager struct {
	mu            sync.RWMutex
	broadcastPool *sync.Pool
	batchSize     int
	maxWorkers    int
}

// BroadcastTask 广播任务
type BroadcastTask struct {
	Message     []byte
	Connections []*Connection
	ExcludeUser string
}

// NewBroadcastManager 创建一个新的广播管理器
func NewBroadcastManager(batchSize, maxWorkers int) *BroadcastManager {
	return &BroadcastManager{
		broadcastPool: &sync.Pool{
			New: func() interface{} {
				return &BroadcastTask{}
			},
		},
		batchSize:  batchSize,
		maxWorkers: maxWorkers,
	}
}

// DefaultBroadcastManager 全局默认广播管理器
var DefaultBroadcastManager = NewBroadcastManager(100, 10)

// Broadcast 广播消息
func (bm *BroadcastManager) Broadcast(message []byte, connections []*Connection, excludeUser string) int {
	if len(connections) == 0 {
		return 0
	}

	// 批量处理广播
	batches := bm.batchConnections(connections, bm.batchSize)
	sent := 0

	// 并行处理批次
	var wg sync.WaitGroup
	results := make(chan int, len(batches))

	// 限制并发数
	semaphore := make(chan struct{}, bm.maxWorkers)

	for _, batch := range batches {
		wg.Add(1)
		semaphore <- struct{}{}

		go func(batch []*Connection) {
			defer func() {
				wg.Done()
				<-semaphore
			}()

			// 处理批次
			batchSent := bm.processBatch(message, batch, excludeUser)
			results <- batchSent
		}(batch)
	}

	// 等待所有批次处理完成
	wg.Wait()
	close(results)

	// 收集结果
	for batchSent := range results {
		sent += batchSent
	}

	return sent
}

// batchConnections 批量处理连接
func (bm *BroadcastManager) batchConnections(connections []*Connection, batchSize int) [][]*Connection {
	var batches [][]*Connection

	for i := 0; i < len(connections); i += batchSize {
		end := i + batchSize
		if end > len(connections) {
			end = len(connections)
		}
		batches = append(batches, connections[i:end])
	}

	return batches
}

// processBatch 处理批次
func (bm *BroadcastManager) processBatch(message []byte, connections []*Connection, excludeUser string) int {
	sent := 0

	for _, conn := range connections {
		// 跳过排除的用户
		if conn.UserID == excludeUser {
			continue
		}

		// 发送消息
		if conn != nil && conn.Conn != nil {
			conn.writeMu.Lock()
			err := conn.Conn.WriteMessage(1, message) // 1 = TextMessage
			conn.writeMu.Unlock()

			if err == nil {
				sent++
			} else {
				// 移除无效连接
				logx.Errorf("Error broadcasting message to user %s: %v", conn.UserID, err)
				DefaultManager.RemoveConnection(conn)
				DefaultHeartbeatManager.RemoveConnection(conn)
			}
		}
	}

	return sent
}

// BroadcastToRoom 广播消息到房间
func (bm *BroadcastManager) BroadcastToRoom(roomID string, message []byte, excludeUser string) int {
	// 获取房间内的连接
	connections := DefaultManager.GetRoomConnections(roomID)
	if len(connections) == 0 {
		return 0
	}

	// 广播消息
	return bm.Broadcast(message, connections, excludeUser)
}

// BroadcastToAll 广播消息到所有连接
func (bm *BroadcastManager) BroadcastToAll(message []byte, excludeUser string) int {
	// 获取所有连接
	var connections []*Connection

	DefaultManager.mu.RLock()
	for _, userConns := range DefaultManager.connections {
		for conn := range userConns {
			connections = append(connections, conn)
		}
	}
	DefaultManager.mu.RUnlock()

	if len(connections) == 0 {
		return 0
	}

	// 广播消息
	return bm.Broadcast(message, connections, excludeUser)
}

// BroadcastToUsers 广播消息到指定用户列表
func (bm *BroadcastManager) BroadcastToUsers(userIDs []string, message []byte) int {
	// 收集用户的连接
	var connections []*Connection

	for _, userID := range userIDs {
		userConns := DefaultManager.GetUserConnections(userID)
		connections = append(connections, userConns...)
	}

	if len(connections) == 0 {
		return 0
	}

	// 广播消息
	return bm.Broadcast(message, connections, "")
}

// OptimizedBroadcastManager 优化的广播管理器
type OptimizedBroadcastManager struct {
	mu          sync.RWMutex
	roomChannels map[string]chan []byte
	userChannels map[string]chan []byte
	closed       bool
}

// NewOptimizedBroadcastManager 创建一个新的优化广播管理器
func NewOptimizedBroadcastManager() *OptimizedBroadcastManager {
	manager := &OptimizedBroadcastManager{
		roomChannels: make(map[string]chan []byte),
		userChannels: make(map[string]chan []byte),
	}

	return manager
}

// DefaultOptimizedBroadcastManager 全局默认优化广播管理器
var DefaultOptimizedBroadcastManager = NewOptimizedBroadcastManager()

// RegisterRoom 注册房间广播通道
func (obm *OptimizedBroadcastManager) RegisterRoom(roomID string) {
	obm.mu.Lock()
	defer obm.mu.Unlock()

	if _, ok := obm.roomChannels[roomID]; !ok {
		obm.roomChannels[roomID] = make(chan []byte, 100)
		// 启动房间广播协程
		go obm.roomBroadcastLoop(roomID)
		logx.Infof("Registered room broadcast channel for room %s", roomID)
	}
}

// UnregisterRoom 取消注册房间广播通道
func (obm *OptimizedBroadcastManager) UnregisterRoom(roomID string) {
	obm.mu.Lock()
	defer obm.mu.Unlock()

	if ch, ok := obm.roomChannels[roomID]; ok {
		close(ch)
		delete(obm.roomChannels, roomID)
		logx.Infof("Unregistered room broadcast channel for room %s", roomID)
	}
}

// RegisterUser 注册用户广播通道
func (obm *OptimizedBroadcastManager) RegisterUser(userID string) {
	obm.mu.Lock()
	defer obm.mu.Unlock()

	if _, ok := obm.userChannels[userID]; !ok {
		obm.userChannels[userID] = make(chan []byte, 100)
		// 启动用户广播协程
		go obm.userBroadcastLoop(userID)
		logx.Infof("Registered user broadcast channel for user %s", userID)
	}
}

// UnregisterUser 取消注册用户广播通道
func (obm *OptimizedBroadcastManager) UnregisterUser(userID string) {
	obm.mu.Lock()
	defer obm.mu.Unlock()

	if ch, ok := obm.userChannels[userID]; ok {
		close(ch)
		delete(obm.userChannels, userID)
		logx.Infof("Unregistered user broadcast channel for user %s", userID)
	}
}

// BroadcastToRoom 广播消息到房间
func (obm *OptimizedBroadcastManager) BroadcastToRoom(roomID string, message []byte) {
	obm.mu.RLock()
	ch, ok := obm.roomChannels[roomID]
	obm.mu.RUnlock()

	if ok {
		select {
		case ch <- message:
			// 消息成功发送到通道
		default:
			// 通道已满，使用普通广播
			DefaultBroadcastManager.BroadcastToRoom(roomID, message, "")
		}
	} else {
		// 房间通道不存在，使用普通广播
		DefaultBroadcastManager.BroadcastToRoom(roomID, message, "")
	}
}

// BroadcastToUser 广播消息到用户
func (obm *OptimizedBroadcastManager) BroadcastToUser(userID string, message []byte) {
	obm.mu.RLock()
	ch, ok := obm.userChannels[userID]
	obm.mu.RUnlock()

	if ok {
		select {
		case ch <- message:
			// 消息成功发送到通道
		default:
			// 通道已满，使用普通广播
			DefaultManager.SendToUser(userID, message)
		}
	} else {
		// 用户通道不存在，使用普通广播
		DefaultManager.SendToUser(userID, message)
	}
}

// roomBroadcastLoop 房间广播循环
func (obm *OptimizedBroadcastManager) roomBroadcastLoop(roomID string) {
	for message := range obm.roomChannels[roomID] {
		// 使用普通广播发送消息
		DefaultBroadcastManager.BroadcastToRoom(roomID, message, "")
	}
}

// userBroadcastLoop 用户广播循环
func (obm *OptimizedBroadcastManager) userBroadcastLoop(userID string) {
	for message := range obm.userChannels[userID] {
		// 使用普通广播发送消息
		DefaultManager.SendToUser(userID, message)
	}
}

// Close 关闭广播管理器
func (obm *OptimizedBroadcastManager) Close() {
	obm.mu.Lock()
	defer obm.mu.Unlock()

	if obm.closed {
		return
	}

	// 关闭所有房间通道
	for roomID, ch := range obm.roomChannels {
		close(ch)
		delete(obm.roomChannels, roomID)
	}

	// 关闭所有用户通道
	for userID, ch := range obm.userChannels {
		close(ch)
		delete(obm.userChannels, userID)
	}

	obm.closed = true
	logx.Info("Closed optimized broadcast manager")
}

// GetRoomChannelCount 获取房间通道数
func (obm *OptimizedBroadcastManager) GetRoomChannelCount() int {
	obm.mu.RLock()
	defer obm.mu.RUnlock()

	return len(obm.roomChannels)
}

// GetUserChannelCount 获取用户通道数
func (obm *OptimizedBroadcastManager) GetUserChannelCount() int {
	obm.mu.RLock()
	defer obm.mu.RUnlock()

	return len(obm.userChannels)
}
