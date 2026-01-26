package chathub

import (
	"sync"

	"github.com/gorilla/websocket"
)

type Hub struct {
	mu    sync.RWMutex
	conns map[string]map[*websocket.Conn]struct{}
}

func NewHub() *Hub {
	return &Hub{
		conns: make(map[string]map[*websocket.Conn]struct{}),
	}
}

var DefaultHub = NewHub()

func (h *Hub) AddConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	set, ok := h.conns[userID]
	if !ok {
		set = make(map[*websocket.Conn]struct{})
		h.conns[userID] = set
	}
	set[conn] = struct{}{}
}

func (h *Hub) RemoveConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	set, ok := h.conns[userID]
	if !ok {
		return
	}
	delete(set, conn)
	if len(set) == 0 {
		delete(h.conns, userID)
	}
}

func (h *Hub) IsOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	set, ok := h.conns[userID]
	return ok && len(set) > 0
}

func (h *Hub) OnlineUserIDs() []string {
	h.mu.RLock()
	defer h.mu.RUnlock()
	ids := make([]string, 0, len(h.conns))
	for id, set := range h.conns {
		if len(set) == 0 {
			continue
		}
		ids = append(ids, id)
	}
	return ids
}

func (h *Hub) GetConn(userID string) *websocket.Conn {
	h.mu.RLock()
	defer h.mu.RUnlock()
	set := h.conns[userID]
	for c := range set {
		if c != nil {
			return c
		}
	}
	return nil
}

func (h *Hub) GetConns(userID string) []*websocket.Conn {
	h.mu.RLock()
	defer h.mu.RUnlock()
	set := h.conns[userID]
	if len(set) == 0 {
		return nil
	}
	out := make([]*websocket.Conn, 0, len(set))
	for c := range set {
		if c == nil {
			continue
		}
		out = append(out, c)
	}
	return out
}
