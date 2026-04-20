package websocket

import (
	"sync"
	"time"

	"github.com/zeromicro/go-zero/core/logx"
)

// Session 表示一个WebSocket会话
type Session struct {
	SessionID    string
	UserID       string
	CreatedAt    time.Time
	LastActivity time.Time
	ExpiresAt    time.Time
	Data         map[string]interface{}
	mu           sync.RWMutex
}

// SessionManager 管理WebSocket会话
type SessionManager struct {
	mu       sync.RWMutex
	sessions map[string]*Session
	expiry   time.Duration
}

// NewSessionManager 创建一个新的会话管理器
func NewSessionManager(expiry time.Duration) *SessionManager {
	manager := &SessionManager{
		sessions: make(map[string]*Session),
		expiry:   expiry,
	}

	// 启动会话清理协程
	go manager.cleanupExpiredSessions()

	return manager
}

// DefaultSessionManager 全局默认会话管理器
var DefaultSessionManager = NewSessionManager(24 * time.Hour)

// CreateSession 创建一个新的会话
func (sm *SessionManager) CreateSession(sessionID, userID string) *Session {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	now := time.Now()
	session := &Session{
		SessionID:    sessionID,
		UserID:       userID,
		CreatedAt:    now,
		LastActivity: now,
		ExpiresAt:    now.Add(sm.expiry),
		Data:         make(map[string]interface{}),
	}

	sm.sessions[sessionID] = session
	logx.Infof("Created new session %s for user %s", sessionID, userID)
	return session
}

// GetSession 获取会话
func (sm *SessionManager) GetSession(sessionID string) *Session {
	sm.mu.RLock()
	session, ok := sm.sessions[sessionID]
	sm.mu.RUnlock()

	if !ok {
		return nil
	}

	// 检查会话是否过期
	if time.Now().After(session.ExpiresAt) {
		sm.RemoveSession(sessionID)
		return nil
	}

	// 更新最后活动时间
	session.mu.Lock()
	session.LastActivity = time.Now()
	session.ExpiresAt = time.Now().Add(sm.expiry)
	session.mu.Unlock()

	return session
}

// RemoveSession 移除会话
func (sm *SessionManager) RemoveSession(sessionID string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if session, ok := sm.sessions[sessionID]; ok {
		logx.Infof("Removed session %s for user %s", sessionID, session.UserID)
		delete(sm.sessions, sessionID)
	}
}

// GetUserSessions 获取用户的所有会话
func (sm *SessionManager) GetUserSessions(userID string) []*Session {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	sessions := make([]*Session, 0)
	now := time.Now()

	for _, session := range sm.sessions {
		if session.UserID == userID && !now.After(session.ExpiresAt) {
			sessions = append(sessions, session)
		}
	}

	return sessions
}

// SetSessionData 设置会话数据
func (s *Session) SetSessionData(key string, value interface{}) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.Data[key] = value
}

// GetSessionData 获取会话数据
func (s *Session) GetSessionData(key string) interface{} {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.Data[key]
}

// RemoveSessionData 移除会话数据
func (s *Session) RemoveSessionData(key string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	delete(s.Data, key)
}

// cleanupExpiredSessions 清理过期会话
func (sm *SessionManager) cleanupExpiredSessions() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		<-ticker.C
		sm.cleanup()
	}
}

// cleanup 执行会话清理
func (sm *SessionManager) cleanup() {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	now := time.Now()
	expired := 0

	for sessionID, session := range sm.sessions {
		if now.After(session.ExpiresAt) {
			delete(sm.sessions, sessionID)
			expired++
		}
	}

	if expired > 0 {
		logx.Infof("Cleaned up %d expired sessions", expired)
	}
}

// GetSessionCount 获取会话总数
func (sm *SessionManager) GetSessionCount() int {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	return len(sm.sessions)
}

// GetUserSessionCount 获取用户的会话数
func (sm *SessionManager) GetUserSessionCount(userID string) int {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	count := 0
	now := time.Now()

	for _, session := range sm.sessions {
		if session.UserID == userID && !now.After(session.ExpiresAt) {
			count++
		}
	}

	return count
}
