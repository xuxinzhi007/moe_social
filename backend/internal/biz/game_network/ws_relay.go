package gamenetwork

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"backend/utils"

	"github.com/gorilla/websocket"
)

const (
	maxRoomIDLength   = 64
	maxPeerCount      = 2
	maxFrameSize      = 128 * 1024
	readTimeout       = 90 * time.Second
	relayPingInterval = 30 * time.Second
)

var relayUpgrader = websocket.Upgrader{
	CheckOrigin: func(*http.Request) bool { return true },
}

var defaultRelay = NewRelay()

// Relay is an in-memory two-peer WebSocket relay for the Android experiment.
type Relay struct {
	mu    sync.Mutex
	rooms map[string]map[*peer]struct{}
}

type peer struct {
	conn    *websocket.Conn
	roomID  string
	userID  uint64
	role    string
	ip      string
	writeMu sync.Mutex
}

// NewRelay creates an empty game-network relay.
func NewRelay() *Relay {
	return &Relay{rooms: make(map[string]map[*peer]struct{})}
}

// ServeWS upgrades an authenticated request and relays binary TUN frames to
// the other peer in the same room.
func ServeWS(w http.ResponseWriter, r *http.Request) {
	token := extractToken(r)
	claims, err := utils.ParseToken(token)
	if err != nil || claims.UserID == 0 {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	roomID := strings.TrimSpace(r.URL.Query().Get("room_id"))
	role := strings.TrimSpace(r.URL.Query().Get("role"))
	virtualIP := strings.TrimSpace(r.URL.Query().Get("virtual_ip"))
	if !validRoomID(roomID) || !validRole(role) || net.ParseIP(virtualIP) == nil {
		http.Error(w, "Invalid game network parameters", http.StatusBadRequest)
		return
	}

	conn, err := relayUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	p := &peer{
		conn:   conn,
		roomID: roomID,
		userID: uint64(claims.UserID),
		role:   role,
		ip:     virtualIP,
	}
	if err := defaultRelay.join(p); err != nil {
		_ = p.writeJSON(map[string]any{
			"type":    "error",
			"message": err.Error(),
		})
		_ = conn.Close()
		return
	}
	defer defaultRelay.leave(p)

	_ = p.writeJSON(map[string]any{
		"type":       "joined",
		"room_id":    roomID,
		"role":       role,
		"virtual_ip": virtualIP,
	})
	defaultRelay.broadcastRoom(roomID, map[string]any{
		"type":  "peer_joined",
		"count": defaultRelay.peerCount(roomID),
	})
	p.readLoop(defaultRelay)
}

func (r *Relay) join(p *peer) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	room := r.rooms[p.roomID]
	if room == nil {
		room = make(map[*peer]struct{})
		r.rooms[p.roomID] = room
	}
	if len(room) >= maxPeerCount {
		return fmt.Errorf("房间已满")
	}
	for existing := range room {
		if existing.role == p.role || existing.ip == p.ip {
			return fmt.Errorf("房间角色或虚拟地址已占用")
		}
	}
	room[p] = struct{}{}
	return nil
}

func (r *Relay) leave(p *peer) {
	r.mu.Lock()
	room := r.rooms[p.roomID]
	if room != nil {
		delete(room, p)
		if len(room) == 0 {
			delete(r.rooms, p.roomID)
		}
	}
	count := len(room)
	r.mu.Unlock()

	if count > 0 {
		r.broadcastRoom(p.roomID, map[string]any{
			"type":  "peer_left",
			"count": count,
		})
	}
}

func (r *Relay) peerCount(roomID string) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.rooms[roomID])
}

func (r *Relay) broadcastRoom(roomID string, message map[string]any) {
	data, err := json.Marshal(message)
	if err != nil {
		return
	}
	for _, p := range r.peers(roomID) {
		_ = p.write(websocket.TextMessage, data)
	}
}

func (r *Relay) broadcastBinary(roomID string, sender *peer, frame []byte) {
	for _, p := range r.peers(roomID) {
		if p == sender {
			continue
		}
		_ = p.write(websocket.BinaryMessage, frame)
	}
}

func (r *Relay) peers(roomID string) []*peer {
	r.mu.Lock()
	defer r.mu.Unlock()
	room := r.rooms[roomID]
	peers := make([]*peer, 0, len(room))
	for p := range room {
		peers = append(peers, p)
	}
	return peers
}

func (p *peer) readLoop(relay *Relay) {
	p.conn.SetReadLimit(maxFrameSize)
	_ = p.conn.SetReadDeadline(time.Now().Add(readTimeout))
	p.conn.SetPongHandler(func(string) error {
		return p.conn.SetReadDeadline(time.Now().Add(readTimeout))
	})

	pingTicker := time.NewTicker(relayPingInterval)
	defer pingTicker.Stop()
	done := make(chan struct{})
	defer close(done)
	go func() {
		for {
			select {
			case <-pingTicker.C:
				if err := p.write(websocket.PingMessage, nil); err != nil {
					_ = p.conn.Close()
					return
				}
			case <-done:
				return
			}
		}
	}()

	for {
		messageType, frame, err := p.conn.ReadMessage()
		if err != nil {
			return
		}
		if err := p.conn.SetReadDeadline(time.Now().Add(readTimeout)); err != nil {
			return
		}
		switch messageType {
		case websocket.BinaryMessage:
			if len(frame) == 0 {
				continue
			}
			relay.broadcastBinary(p.roomID, p, frame)
		case websocket.TextMessage:
			p.handleText(frame)
		}
	}
}

func (p *peer) handleText(frame []byte) {
	var message struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal(frame, &message); err != nil {
		return
	}
	if message.Type == "ping" {
		_ = p.writeJSON(map[string]any{"type": "pong"})
	}
}

func (p *peer) writeJSON(message map[string]any) error {
	data, err := json.Marshal(message)
	if err != nil {
		return err
	}
	return p.write(websocket.TextMessage, data)
}

func (p *peer) write(messageType int, data []byte) error {
	p.writeMu.Lock()
	defer p.writeMu.Unlock()
	return p.conn.WriteMessage(messageType, data)
}

func extractToken(r *http.Request) string {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	if auth != "" {
		return auth
	}
	return strings.TrimSpace(r.URL.Query().Get("token"))
}

func validRoomID(roomID string) bool {
	if roomID == "" || len(roomID) > maxRoomIDLength {
		return false
	}
	for _, char := range roomID {
		if (char >= 'a' && char <= 'z') ||
			(char >= 'A' && char <= 'Z') ||
			(char >= '0' && char <= '9') ||
			char == '-' || char == '_' {
			continue
		}
		return false
	}
	return true
}

func validRole(role string) bool {
	return role == "host" || role == "guest"
}
