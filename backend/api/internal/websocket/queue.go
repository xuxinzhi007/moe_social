package websocket

import (
	"sync"
	"time"

	"github.com/zeromicro/go-zero/core/logx"
)

// MessageQueue 消息队列接口
type MessageQueue interface {
	Enqueue(message *QueuedMessage)
	Dequeue() *QueuedMessage
	Size() int
	Close()
}

// QueuedMessage 队列中的消息
type QueuedMessage struct {
	Message    []byte
	UserID     string
	ConnType   ConnectionType
	RoomID     string
	Timestamp  time.Time
	Retries    int
	MaxRetries int
}

// SimpleMessageQueue 简单消息队列实现
type SimpleMessageQueue struct {
	mu      sync.RWMutex
	queue   chan *QueuedMessage
	closed  bool
	workers int
}

// NewMessageQueue 创建一个新的消息队列
func NewMessageQueue(size int, workers int) *SimpleMessageQueue {
	queue := &SimpleMessageQueue{
		queue:   make(chan *QueuedMessage, size),
		workers: workers,
	}

	// 启动工作协程
	for i := 0; i < workers; i++ {
		go queue.worker()
	}

	return queue
}

// DefaultMessageQueue 全局默认消息队列
var DefaultMessageQueue = NewMessageQueue(1000, 5)

// Enqueue 入队消息
func (q *SimpleMessageQueue) Enqueue(message *QueuedMessage) {
	if q == nil || message == nil {
		return
	}

	q.mu.RLock()
	if q.closed {
		q.mu.RUnlock()
		return
	}
	q.mu.RUnlock()

	select {
	case q.queue <- message:
		// 消息成功入队
		logx.Infof("Enqueued message for user %s, type %s", message.UserID, message.ConnType)
	default:
		// 队列已满，丢弃消息
		logx.Errorf("Message queue full, dropping message for user %s", message.UserID)
	}
}

// Dequeue 出队消息
func (q *SimpleMessageQueue) Dequeue() *QueuedMessage {
	if q == nil {
		return nil
	}

	q.mu.RLock()
	if q.closed {
		q.mu.RUnlock()
		return nil
	}
	q.mu.RUnlock()

	select {
	case message := <-q.queue:
		return message
	default:
		return nil
	}
}

// Size 获取队列大小
func (q *SimpleMessageQueue) Size() int {
	if q == nil {
		return 0
	}

	return len(q.queue)
}

// Close 关闭队列
func (q *SimpleMessageQueue) Close() {
	if q == nil {
		return
	}

	q.mu.Lock()
	if q.closed {
		q.mu.Unlock()
		return
	}
	q.closed = true
	q.mu.Unlock()

	// 关闭队列
	close(q.queue)

	logx.Info("Closed message queue")
}

// worker 工作协程
func (q *SimpleMessageQueue) worker() {
	for message := range q.queue {
		if message == nil {
			continue
		}

		// 处理消息
		q.processMessage(message)
	}
}

// processMessage 处理消息
func (q *SimpleMessageQueue) processMessage(message *QueuedMessage) {
	// 根据消息类型处理
	switch message.ConnType {
	case ConnectionTypeChat:
		// 发送给指定用户
		if message.UserID != "" {
			sent := DefaultManager.SendToUserByType(message.UserID, ConnectionTypeChat, message.Message)
			if sent == 0 {
				// 消息发送失败，尝试重试
				q.handleFailedMessage(message)
			} else {
				logx.Infof("Processed chat message for user %s", message.UserID)
			}
		}
	case ConnectionTypePresence:
		// 发送在线状态消息
		if message.UserID != "" {
			sent := DefaultManager.SendToUserByType(message.UserID, ConnectionTypePresence, message.Message)
			if sent == 0 {
				// 消息发送失败，尝试重试
				q.handleFailedMessage(message)
			} else {
				logx.Infof("Processed presence message for user %s", message.UserID)
			}
		}
	case ConnectionTypeWorld:
		// 广播到房间
		if message.RoomID != "" {
			sent := DefaultManager.BroadcastToRoom(message.RoomID, message.Message, message.UserID)
			if sent == 0 {
				// 消息发送失败，尝试重试
				q.handleFailedMessage(message)
			} else {
				logx.Infof("Processed world message for room %s", message.RoomID)
			}
		}
	default:
		// 未知消息类型
		logx.Errorf("Unknown message type: %s", message.ConnType)
	}
}

// handleFailedMessage 处理发送失败的消息
func (q *SimpleMessageQueue) handleFailedMessage(message *QueuedMessage) {
	// 检查重试次数
	if message.Retries >= message.MaxRetries {
		logx.Errorf("Max retries reached for message to user %s, dropping message", message.UserID)
		return
	}

	// 增加重试次数
	message.Retries++
	// 延迟重试
	time.Sleep(time.Duration(message.Retries) * 100 * time.Millisecond)

	// 重新入队
	q.Enqueue(message)
	logx.Infof("Retrying message to user %s (attempt %d/%d)", message.UserID, message.Retries, message.MaxRetries)
}

// MessageBuffer 消息缓冲器
type MessageBuffer struct {
	mu      sync.RWMutex
	buffers map[string][]*QueuedMessage
	maxSize int
}

// NewMessageBuffer 创建一个新的消息缓冲器
func NewMessageBuffer(maxSize int) *MessageBuffer {
	return &MessageBuffer{
		buffers: make(map[string][]*QueuedMessage),
		maxSize: maxSize,
	}
}

// DefaultMessageBuffer 全局默认消息缓冲器
var DefaultMessageBuffer = NewMessageBuffer(100)

// AddMessage 添加消息到缓冲器
func (b *MessageBuffer) AddMessage(userID string, message *QueuedMessage) {
	if b == nil || message == nil {
		return
	}

	b.mu.Lock()
	defer b.mu.Unlock()

	// 确保用户缓冲区存在
	if _, ok := b.buffers[userID]; !ok {
		b.buffers[userID] = make([]*QueuedMessage, 0, b.maxSize)
	}

	// 检查缓冲区大小
	if len(b.buffers[userID]) >= b.maxSize {
		// 移除最早的消息
		b.buffers[userID] = b.buffers[userID][1:]
	}

	// 添加消息
	b.buffers[userID] = append(b.buffers[userID], message)
	logx.Infof("Added message to buffer for user %s, buffer size: %d", userID, len(b.buffers[userID]))
}

// GetMessages 获取用户的缓冲消息
func (b *MessageBuffer) GetMessages(userID string) []*QueuedMessage {
	if b == nil {
		return nil
	}

	b.mu.RLock()
	defer b.mu.RUnlock()

	if messages, ok := b.buffers[userID]; ok {
		// 复制消息
		copy := make([]*QueuedMessage, len(messages))
		for i, msg := range messages {
			copy[i] = msg
		}
		return copy
	}

	return nil
}

// ClearMessages 清除用户的缓冲消息
func (b *MessageBuffer) ClearMessages(userID string) {
	if b == nil {
		return
	}

	b.mu.Lock()
	defer b.mu.Unlock()

	delete(b.buffers, userID)
	logx.Infof("Cleared message buffer for user %s", userID)
}

// GetBufferSize 获取用户的缓冲区大小
func (b *MessageBuffer) GetBufferSize(userID string) int {
	if b == nil {
		return 0
	}

	b.mu.RLock()
	defer b.mu.RUnlock()

	if messages, ok := b.buffers[userID]; ok {
		return len(messages)
	}

	return 0
}

// CleanupInactiveBuffers 清理不活跃的缓冲区
func (b *MessageBuffer) CleanupInactiveBuffers(maxInactiveTime time.Duration) {
	if b == nil {
		return
	}

	b.mu.Lock()
	defer b.mu.Unlock()

	now := time.Now()
	inactiveThreshold := now.Add(-maxInactiveTime)
	removed := 0

	for userID, messages := range b.buffers {
		if len(messages) == 0 {
			delete(b.buffers, userID)
			removed++
		} else {
			// 检查最后一条消息的时间
			lastMsg := messages[len(messages)-1]
			if lastMsg.Timestamp.Before(inactiveThreshold) {
				delete(b.buffers, userID)
				removed++
			}
		}
	}

	if removed > 0 {
		logx.Infof("Cleaned up %d inactive message buffers", removed)
	}
}
