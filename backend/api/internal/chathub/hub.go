package chathub

import (
	"sync"

	"github.com/gorilla/websocket"
)

type Hub struct {
	mu    sync.RWMutex
	conns map[string]*websocket.Conn
}

func NewHub() *Hub {
	return &Hub{
		conns: make(map[string]*websocket.Conn),
	}
}

var DefaultHub = NewHub()

func (h *Hub) AddConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if old, ok := h.conns[userID]; ok && old != conn {
		old.Close()
	}
	h.conns[userID] = conn
}

func (h *Hub) RemoveConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	current, ok := h.conns[userID]
	if !ok {
		return
	}
	if current == conn {
		delete(h.conns, userID)
	}
}

func (h *Hub) IsOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	conn, ok := h.conns[userID]
	return ok && conn != nil
}

func (h *Hub) OnlineUserIDs() []string {
	h.mu.RLock()
	defer h.mu.RUnlock()
	ids := make([]string, 0, len(h.conns))
	for id, c := range h.conns {
		if c == nil {
			continue
		}
		ids = append(ids, id)
	}
	return ids
}

func (h *Hub) GetConn(userID string) *websocket.Conn {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.conns[userID]
}
