package companionbiz

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"

	"backend/internal/platform/moelog"
)

var companionUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 4096,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

type companionMember struct {
	conn    *websocket.Conn
	writeMu sync.Mutex
	done    chan struct{}
	userID  uint // 已订阅的用户 ID
}

func (m *companionMember) writeText(data []byte) bool {
	if m == nil {
		return false
	}
	m.writeMu.Lock()
	defer m.writeMu.Unlock()
	if m.conn == nil {
		return false
	}
	_ = m.conn.SetWriteDeadline(time.Now().Add(8 * time.Second))
	if err := m.conn.WriteMessage(websocket.TextMessage, data); err != nil {
		moelog.Errorf("companion ws write: %v", err)
		return false
	}
	return true
}

func (m *companionMember) writeJSON(v interface{}) bool {
	data, err := json.Marshal(v)
	if err != nil {
		return false
	}
	return m.writeText(data)
}

// CompanionWSHub 管理所有 /ws/companion WebSocket 连接，支持按用户广播。
type CompanionWSHub struct {
	mu      sync.RWMutex
	members map[string]*companionMember // connID -> member
	engine  *Engine
}

// NewCompanionWSHub 创建连接管理器。
func NewCompanionWSHub() *CompanionWSHub {
	return &CompanionWSHub{members: make(map[string]*companionMember)}
}

// SetEngine 注入引擎（引擎创建后调用）。
func (h *CompanionWSHub) SetEngine(e *Engine) {
	h.engine = e
}

// ServeHTTP 处理 WebSocket 升级和连接。
func (h *CompanionWSHub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	conn, err := companionUpgrader.Upgrade(w, r, nil)
	if err != nil {
		moelog.Errorf("companion ws upgrade: %v", err)
		return
	}

	id := fmt.Sprintf("companion-%d", time.Now().UnixNano())
	member := &companionMember{conn: conn, done: make(chan struct{})}

	h.mu.Lock()
	h.members[id] = member
	h.mu.Unlock()

	defer func() {
		h.mu.Lock()
		delete(h.members, id)
		h.mu.Unlock()
		conn.Close()
	}()

	moelog.Infof("companion ws: client connected id=%s", id)

	// 发送当前状态快照
	h.sendGreeting(member)

	// 读循环
	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				moelog.Errorf("companion ws read: %v", err)
			}
			break
		}

		var req map[string]interface{}
		if err := json.Unmarshal(message, &req); err != nil {
			continue
		}
		msgType, _ := req["type"].(string)

		switch msgType {
		case "subscribe":
			userID := uint(1) // TODO: 从 JWT 提取
			h.mu.Lock()
			member.userID = userID
			h.mu.Unlock()
			moelog.Infof("companion ws: client id=%s subscribed user=%d", id, userID)

		case "ping":
			member.writeJSON(map[string]interface{}{"type": "pong"})
		}
	}

	moelog.Infof("companion ws: client disconnected id=%s", id)
}

// sendGreeting 向新连接的客户端发送当前伙伴状态。
func (h *CompanionWSHub) sendGreeting(m *companionMember) {
	if h.engine == nil {
		return
	}
	state, _, err := h.engine.GetState(context.Background(), 1) // TODO: userID from JWT
	if err != nil || state == nil {
		return
	}
	m.writeJSON(map[string]interface{}{
		"type":    "state_snapshot",
		"mood":    state.MoodThought,
		"activity": state.ActivityLabel,
		"greeting": state.Greeting,
	})
}

// Broadcast 广播事件到所有已连接的客户端。
func (h *CompanionWSHub) Broadcast(eventType string, data map[string]interface{}) {
	payload := map[string]interface{}{"type": eventType}
	for k, v := range data {
		payload[k] = v
	}

	raw, err := json.Marshal(payload)
	if err != nil {
		moelog.Errorf("companion ws broadcast marshal: %v", err)
		return
	}

	h.mu.RLock()
	members := make([]*companionMember, 0, len(h.members))
	for _, m := range h.members {
		members = append(members, m)
	}
	h.mu.RUnlock()

	for _, m := range members {
		go func(member *companionMember) {
			member.writeText(raw)
		}(m)
	}
}

// BroadcastGreeting 广播伙伴问候消息。
func (h *CompanionWSHub) BroadcastGreeting(greeting, moodThought, activityLabel string) {
	h.Broadcast("greeting", map[string]interface{}{
		"greeting": greeting,
		"mood":     moodThought,
		"activity": activityLabel,
	})
}

// GetMemberCount 返回当前连接数。
func (h *CompanionWSHub) GetMemberCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.members)
}
