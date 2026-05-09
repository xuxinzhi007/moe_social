package websocket

import (
	"encoding/json"
	"fmt"
	"runtime"
	"strings"
	"sync"

	"github.com/zeromicro/go-zero/core/logx"
)

// ErrorType 错误类型
type ErrorType string

const (
	// ErrorTypeConnection 连接错误
	ErrorTypeConnection ErrorType = "connection"
	// ErrorTypeMessage 消息错误
	ErrorTypeMessage ErrorType = "message"
	// ErrorTypeRateLimit 速率限制错误
	ErrorTypeRateLimit ErrorType = "rate_limit"
	// ErrorTypeAuthorization 授权错误
	ErrorTypeAuthorization ErrorType = "authorization"
	// ErrorTypeInternal 内部错误
	ErrorTypeInternal ErrorType = "internal"
)

// WebSocketError WebSocket错误
type WebSocketError struct {
	Type    ErrorType
	Message string
	Err     error
	Stack   string
}

// Error 实现error接口
func (e *WebSocketError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s error: %s: %v", e.Type, e.Message, e.Err)
	}
	return fmt.Sprintf("%s error: %s", e.Type, e.Message)
}

// NewWebSocketError 创建一个新的WebSocket错误
func NewWebSocketError(errType ErrorType, message string, err error) *WebSocketError {
	return &WebSocketError{
		Type:    errType,
		Message: message,
		Err:     err,
		Stack:   getStack(),
	}
}

// getStack 获取堆栈信息
func getStack() string {
	var buf [4096]byte
	n := runtime.Stack(buf[:], false)
	stack := string(buf[:n])

	// 过滤掉不需要的堆栈信息
	lines := strings.Split(stack, "\n")
	var filteredLines []string
	for i, line := range lines {
		if i > 0 && strings.Contains(line, "websocket/") {
			filteredLines = append(filteredLines, lines[i-1])
			filteredLines = append(filteredLines, line)
		}
	}

	return strings.Join(filteredLines, "\n")
}

// ErrorHandler 错误处理函数类型
type ErrorHandler func(err *WebSocketError, conn *Connection)

// DefaultErrorHandler 默认错误处理函数
func DefaultErrorHandler(err *WebSocketError, conn *Connection) {
	// 记录错误日志
	logx.Errorf("WebSocket error: %v\nStack: %s", err, err.Stack)

	// 根据错误类型处理
	switch err.Type {
	case ErrorTypeConnection:
		// 处理连接错误
		if conn != nil {
			// 移除连接
			DefaultManager.RemoveConnection(conn)
			DefaultHeartbeatManager.RemoveConnection(conn)
		}
	case ErrorTypeMessage:
		// 处理消息错误
		// 可以向客户端发送错误消息
		if conn != nil && conn.Conn != nil {
			errorMsg := map[string]interface{}{
				"type":    "error",
				"message": err.Message,
			}
			msgData, marshalErr := json.Marshal(errorMsg)
			if marshalErr == nil {
				conn.writeMu.Lock()
				conn.Conn.WriteMessage(1, msgData) // 1 = TextMessage
				conn.writeMu.Unlock()
			}
		}
	case ErrorTypeRateLimit:
		// 处理速率限制错误
		if conn != nil && conn.Conn != nil {
			errorMsg := map[string]interface{}{
				"type":    "rate_limit",
				"message": "Rate limit exceeded",
			}
			msgData, marshalErr := json.Marshal(errorMsg)
			if marshalErr == nil {
				conn.writeMu.Lock()
				conn.Conn.WriteMessage(1, msgData) // 1 = TextMessage
				conn.writeMu.Unlock()
			}
		}
	case ErrorTypeAuthorization:
		// 处理授权错误
		if conn != nil && conn.Conn != nil {
			errorMsg := map[string]interface{}{
				"type":    "unauthorized",
				"message": "Unauthorized",
			}
			msgData, marshalErr := json.Marshal(errorMsg)
			if marshalErr == nil {
				conn.writeMu.Lock()
				conn.Conn.WriteMessage(1, msgData) // 1 = TextMessage
				conn.writeMu.Unlock()
			}
			// 关闭连接
			DefaultManager.RemoveConnection(conn)
			DefaultHeartbeatManager.RemoveConnection(conn)
		}
	case ErrorTypeInternal:
		// 处理内部错误
		// 可以向客户端发送通用错误消息
		if conn != nil && conn.Conn != nil {
			errorMsg := map[string]interface{}{
				"type":    "error",
				"message": "Internal server error",
			}
			msgData, marshalErr := json.Marshal(errorMsg)
			if marshalErr == nil {
				conn.writeMu.Lock()
				conn.Conn.WriteMessage(1, msgData) // 1 = TextMessage
				conn.writeMu.Unlock()
			}
		}
	}
}

// ErrorManager 错误管理器
type ErrorManager struct {
	mu           sync.RWMutex
	errorHandler ErrorHandler
	errorCount   map[ErrorType]int
}

// NewErrorManager 创建一个新的错误管理器
func NewErrorManager() *ErrorManager {
	return &ErrorManager{
		errorHandler: DefaultErrorHandler,
		errorCount:   make(map[ErrorType]int),
	}
}

// DefaultErrorManager 全局默认错误管理器
var DefaultErrorManager = NewErrorManager()

// HandleError 处理错误
func (em *ErrorManager) HandleError(err *WebSocketError, conn *Connection) {
	// 增加错误计数
	em.mu.Lock()
	em.errorCount[err.Type]++
	em.mu.Unlock()

	// 调用错误处理函数
	em.errorHandler(err, conn)
}

// SetErrorHandler 设置错误处理函数
func (em *ErrorManager) SetErrorHandler(handler ErrorHandler) {
	em.mu.Lock()
	defer em.mu.Unlock()

	em.errorHandler = handler
	logx.Info("Set custom error handler")
}

// GetErrorCount 获取错误计数
func (em *ErrorManager) GetErrorCount(errType ErrorType) int {
	em.mu.RLock()
	defer em.mu.RUnlock()

	return em.errorCount[errType]
}

// GetAllErrorCounts 获取所有错误计数
func (em *ErrorManager) GetAllErrorCounts() map[ErrorType]int {
	em.mu.RLock()
	defer em.mu.RUnlock()

	counts := make(map[ErrorType]int)
	for errType, count := range em.errorCount {
		counts[errType] = count
	}

	return counts
}

// ResetErrorCounts 重置错误计数
func (em *ErrorManager) ResetErrorCounts() {
	em.mu.Lock()
	defer em.mu.Unlock()

	em.errorCount = make(map[ErrorType]int)
	logx.Info("Reset error counts")
}

// Recover 恢复函数，用于捕获panic
func Recover(conn *Connection) {
	if r := recover(); r != nil {
		// 创建错误
		err := NewWebSocketError(ErrorTypeInternal, "Panic recovered", fmt.Errorf("%v", r))
		// 处理错误
		DefaultErrorManager.HandleError(err, conn)
		// 记录错误
		logx.Errorf("Panic recovered: %v\nStack: %s", r, err.Stack)
	}
}

// SafeExecute 安全执行函数
func SafeExecute(conn *Connection, fn func()) {
	defer Recover(conn)
	fn()
}
