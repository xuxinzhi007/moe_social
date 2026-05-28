package chatbiz

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"backend/utils"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/core/logx"
)

var (
	worldRoomsMutex sync.RWMutex
	worldRooms      = make(map[string]map[string]*worldMember)
)

type worldMember struct {
	writeMu           sync.Mutex
	conn              *websocket.Conn
	x, y              float64
	username          string
	lastMoveBroadcast time.Time
}

func (m *worldMember) writeJSON(msg interface{}) bool {
	if m == nil {
		return false
	}
	data, err := json.Marshal(msg)
	if err != nil {
		return false
	}
	return m.writeText(data)
}

func (m *worldMember) writeText(data []byte) bool {
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
		logx.Errorf("world ws write: %v", err)
		return false
	}
	return true
}

var worldRoomPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,48}$`)

const worldMoveBroadcastMinInterval = 40 * time.Millisecond

// ServeWorldWS 升级 /ws/world 连接（tier-A 入口）。
func ServeWorldWS(w http.ResponseWriter, r *http.Request) {
	token := extractWSToken(r)
	if token == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	claims, err := utils.ParseToken(token)
	if err != nil {
		http.Error(w, "Invalid token", http.StatusUnauthorized)
		return
	}

	userID := fmt.Sprintf("%d", claims.UserID)
	roomID := strings.TrimSpace(r.URL.Query().Get("room"))
	if roomID == "" {
		roomID = "default"
	}
	if !worldRoomPattern.MatchString(roomID) {
		http.Error(w, "Invalid room", http.StatusBadRequest)
		return
	}

	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		logx.Errorf("world ws upgrade: %v", err)
		return
	}

	sx, sy := worldPickSpawn(userID)

	worldRoomsMutex.Lock()
	room := worldRooms[roomID]
	if room == nil {
		room = make(map[string]*worldMember)
		worldRooms[roomID] = room
	}
	if old, exists := room[userID]; exists && old != nil && old.conn != nil {
		old.writeMu.Lock()
		_ = old.conn.Close()
		old.conn = nil
		old.writeMu.Unlock()
	}
	member := &worldMember{conn: conn, x: sx, y: sy}
	room[userID] = member
	worldRoomsMutex.Unlock()

	peers := make([]map[string]interface{}, 0)
	worldRoomsMutex.RLock()
	if rmap, ok := worldRooms[roomID]; ok {
		for uid, m := range rmap {
			if uid == userID || m == nil {
				continue
			}
			peers = append(peers, map[string]interface{}{
				"user_id":  uid,
				"x":        m.x,
				"y":        m.y,
				"username": m.username,
			})
		}
	}
	worldRoomsMutex.RUnlock()

	if !member.writeJSON(map[string]interface{}{
		"type":    "world_welcome",
		"user_id": userID,
		"room":    roomID,
		"x":       sx,
		"y":       sy,
		"peers":   peers,
	}) {
		worldLeaveRoom(roomID, userID)
		return
	}

	worldBroadcast(roomID, userID, map[string]interface{}{
		"type":     "world_peer_joined",
		"user_id":  userID,
		"x":        sx,
		"y":        sy,
		"username": "",
	})

	go handleWorldWSLoop(roomID, userID, conn)
}

func worldPickSpawn(userID string) (float64, float64) {
	h := uint32(2166136261)
	for _, c := range userID {
		h ^= uint32(c)
		h *= 16777619
	}
	dx := float64(h%120) - 40
	dy := float64((h>>8)%100) - 30
	return 640.0 + dx, 360.0 + dy
}

func sanitizeWorldUsername(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	var b strings.Builder
	n := 0
	for _, r := range s {
		if n >= 24 {
			break
		}
		if r < 32 || r == 127 {
			continue
		}
		b.WriteRune(r)
		n++
	}
	return strings.TrimSpace(b.String())
}

func worldBroadcast(roomID string, excludeUserID string, msg interface{}) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	worldRoomsMutex.RLock()
	room, ok := worldRooms[roomID]
	if !ok {
		worldRoomsMutex.RUnlock()
		return
	}
	recipients := make([]*worldMember, 0, len(room))
	for uid, m := range room {
		if excludeUserID != "" && uid == excludeUserID {
			continue
		}
		if m != nil && m.conn != nil {
			recipients = append(recipients, m)
		}
	}
	worldRoomsMutex.RUnlock()
	for _, m := range recipients {
		_ = m.writeText(data)
	}
}

func worldMemberLookup(roomID, userID string) *worldMember {
	worldRoomsMutex.RLock()
	defer worldRoomsMutex.RUnlock()
	if room, ok := worldRooms[roomID]; ok {
		return room[userID]
	}
	return nil
}

func worldLeaveRoom(roomID, userID string) {
	worldRoomsMutex.Lock()
	defer worldRoomsMutex.Unlock()
	room, ok := worldRooms[roomID]
	if !ok {
		return
	}
	m := room[userID]
	delete(room, userID)
	if len(room) == 0 {
		delete(worldRooms, roomID)
	}
	if m != nil && m.conn != nil {
		m.writeMu.Lock()
		_ = m.conn.Close()
		m.conn = nil
		m.writeMu.Unlock()
	}
}

func handleWorldWSLoop(roomID, userID string, conn *websocket.Conn) {
	defer func() {
		worldLeaveRoom(roomID, userID)
		logx.Infof("World ws user %s left room %s", userID, roomID)
		worldBroadcast(roomID, "", map[string]interface{}{
			"type":    "world_peer_left",
			"user_id": userID,
		})
	}()

	conn.SetReadDeadline(time.Now().Add(75 * time.Second))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(75 * time.Second))
		return nil
	})

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				logx.Errorf("World ws read: %v", err)
			}
			break
		}
		conn.SetReadDeadline(time.Now().Add(75 * time.Second))
		handleWorldWSMessage(roomID, userID, message)
	}
}

func handleWorldWSMessage(roomID, userID string, message []byte) {
	var msg map[string]interface{}
	if err := json.Unmarshal(message, &msg); err != nil {
		return
	}
	msgType, ok := msg["type"].(string)
	if !ok {
		return
	}
	switch msgType {
	case "ping":
		if m := worldMemberLookup(roomID, userID); m != nil {
			m.writeJSON(map[string]interface{}{"type": "pong"})
		}
	case "world_move":
		x, xok := toFloat(msg["x"])
		y, yok := toFloat(msg["y"])
		if !xok || !yok {
			return
		}
		var shouldBroadcast bool
		worldRoomsMutex.Lock()
		if room, ok := worldRooms[roomID]; ok {
			if m, ok := room[userID]; ok && m != nil {
				m.x, m.y = x, y
				if time.Since(m.lastMoveBroadcast) >= worldMoveBroadcastMinInterval {
					m.lastMoveBroadcast = time.Now()
					shouldBroadcast = true
				}
			}
		}
		worldRoomsMutex.Unlock()
		if shouldBroadcast {
			worldBroadcast(roomID, userID, map[string]interface{}{
				"type":    "world_move",
				"user_id": userID,
				"x":       x,
				"y":       y,
			})
		}
	case "world_profile":
		uname := sanitizeWorldUsername(fmt.Sprint(msg["username"]))
		worldRoomsMutex.Lock()
		if room, ok := worldRooms[roomID]; ok {
			if m, ok := room[userID]; ok && m != nil {
				m.username = uname
			}
		}
		worldRoomsMutex.Unlock()
		worldBroadcast(roomID, "", map[string]interface{}{
			"type":     "world_peer_profile",
			"user_id":  userID,
			"username": uname,
		})
	case "world_chat":
		content := fmt.Sprint(msg["content"])
		if content == "" {
			return
		}
		var senderUsername string
		worldRoomsMutex.RLock()
		if room, ok := worldRooms[roomID]; ok {
			if m, ok := room[userID]; ok && m != nil {
				senderUsername = m.username
			}
		}
		worldRoomsMutex.RUnlock()
		if senderUsername == "" {
			senderUsername = "玩家"
		}
		logx.Infof("World chat from %s (%s): %s", userID, senderUsername, content)
		worldBroadcast(roomID, "", map[string]interface{}{
			"type":     "world_chat",
			"user_id":  userID,
			"username": senderUsername,
			"content":  content,
		})
	}
}

func toFloat(v interface{}) (float64, bool) {
	switch t := v.(type) {
	case float64:
		return t, true
	case json.Number:
		f, err := t.Float64()
		return f, err == nil
	default:
		return 0, false
	}
}
