package battleapp

import (
	"encoding/json"
	"sync"
	"time"

	battlev1 "backend/api/battle/v1"

	"github.com/gorilla/websocket"
)

// Hub manages room-scoped battle WebSocket subscribers.
type Hub struct {
	mu    sync.RWMutex
	rooms map[uint]map[*websocket.Conn]struct{}
}

// NewHub creates an empty room-scoped WebSocket hub.
func NewHub() *Hub { return &Hub{rooms: make(map[uint]map[*websocket.Conn]struct{})} }

// Serve upgrades a verified request, sends a snapshot, and blocks until close.
func (h *Hub) Serve(conn *websocket.Conn, roomID uint, snapshot *battlev1.BattleRoomSnapshot) {
	h.add(roomID, conn)
	defer h.remove(roomID, conn)
	_ = h.write(conn, envelope{Type: "snapshot", RoomID: uint64(roomID), Seq: snapshot.GetLastEventSeq(), ServerTime: time.Now().UTC(), Payload: snapshot})
	for {
		if _, _, err := conn.NextReader(); err != nil {
			return
		}
	}
}

// PublishGift broadcasts a committed gift event to one room.
func (h *Hub) PublishGift(event *battlev1.BattleGiftEvent, snapshot *battlev1.BattleRoomSnapshot) {
	if event == nil || snapshot == nil {
		return
	}
	h.broadcast(snapshot.GetRoomId(), envelope{Type: "gift_sent", RoomID: snapshot.GetRoomId(), Seq: event.GetEventSeq(), ServerTime: time.Now().UTC(), Payload: map[string]any{"event": event, "room": snapshot}})
}

// PublishSnapshot broadcasts a durable lifecycle snapshot to its room.
func (h *Hub) PublishSnapshot(kind string, snapshot *battlev1.BattleRoomSnapshot) {
	if snapshot == nil {
		return
	}
	h.broadcast(snapshot.GetRoomId(), envelope{Type: kind, RoomID: snapshot.GetRoomId(), Seq: snapshot.GetLastEventSeq(), ServerTime: time.Now().UTC(), Payload: snapshot})
}

type envelope struct {
	Type       string    `json:"type"`
	RoomID     uint64    `json:"room_id"`
	Seq        uint64    `json:"seq"`
	ServerTime time.Time `json:"server_time"`
	Payload    any       `json:"payload"`
}

func (h *Hub) add(roomID uint, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.rooms[roomID] == nil {
		h.rooms[roomID] = make(map[*websocket.Conn]struct{})
	}
	h.rooms[roomID][conn] = struct{}{}
}
func (h *Hub) remove(roomID uint, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(h.rooms[roomID], conn)
	if len(h.rooms[roomID]) == 0 {
		delete(h.rooms, roomID)
	}
}
func (h *Hub) broadcast(roomID uint64, message envelope) {
	h.mu.RLock()
	clients := make([]*websocket.Conn, 0, len(h.rooms[uint(roomID)]))
	for conn := range h.rooms[uint(roomID)] {
		clients = append(clients, conn)
	}
	h.mu.RUnlock()
	for _, conn := range clients {
		if err := h.write(conn, message); err != nil {
			h.remove(uint(roomID), conn)
			_ = conn.Close()
		}
	}
}
func (h *Hub) write(conn *websocket.Conn, message envelope) error {
	bytes, err := json.Marshal(message)
	if err != nil {
		return err
	}
	return conn.WriteMessage(websocket.TextMessage, bytes)
}
