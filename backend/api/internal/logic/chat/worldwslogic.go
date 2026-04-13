package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"backend/api/internal/svc"
	"backend/utils"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/core/logx"
)

var (
	worldRoomsMutex sync.RWMutex
	worldRooms      = make(map[string]map[string]*worldMember)
)

type worldMember struct {
	conn *websocket.Conn
	x, y float64
}

var worldRoomPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,48}$`)

// WorldWsLogic 大世界同步：同 room 内广播位置，供 Godot 等客户端走 wss 远程联机。
type WorldWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewWorldWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WorldWsLogic {
	return &WorldWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
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
	recipients := make([]*websocket.Conn, 0, len(room))
	for uid, m := range room {
		if uid != excludeUserID && m != nil && m.conn != nil {
			recipients = append(recipients, m.conn)
		}
	}
	worldRoomsMutex.RUnlock()
	deadline := time.Now().Add(8 * time.Second)
	for _, c := range recipients {
		_ = c.SetWriteDeadline(deadline)
		if err := c.WriteMessage(websocket.TextMessage, data); err != nil {
			logx.Errorf("world ws broadcast write: %v", err)
		}
	}
}

func worldSendJSON(conn *websocket.Conn, msg interface{}) bool {
	data, err := json.Marshal(msg)
	if err != nil {
		return false
	}
	_ = conn.SetWriteDeadline(time.Now().Add(8 * time.Second))
	return conn.WriteMessage(websocket.TextMessage, data) == nil
}

func worldLeaveRoom(roomID, userID string) {
	worldRoomsMutex.Lock()
	defer worldRoomsMutex.Unlock()
	room, ok := worldRooms[roomID]
	if !ok {
		return
	}
	delete(room, userID)
	if len(room) == 0 {
		delete(worldRooms, roomID)
	}
}

func (l *WorldWsLogic) WorldWs() error {
	r, ok := l.ctx.Value("http.Request").(*http.Request)
	if !ok {
		return nil
	}

	w, ok := l.ctx.Value("http.ResponseWriter").(*http.ResponseWriter)
	if !ok {
		return nil
	}

	token := r.Header.Get("Authorization")
	if token == "" {
		token = r.URL.Query().Get("token")
		if token == "" {
			http.Error(*w, "Unauthorized", http.StatusUnauthorized)
			return nil
		}
	} else if strings.HasPrefix(token, "Bearer ") {
		token = strings.TrimPrefix(token, "Bearer ")
	}

	claims, err := utils.ParseToken(token)
	if err != nil {
		http.Error(*w, "Invalid token", http.StatusUnauthorized)
		return nil
	}

	userID := fmt.Sprintf("%d", claims.UserID)
	roomID := strings.TrimSpace(r.URL.Query().Get("room"))
	if roomID == "" {
		roomID = "default"
	}
	if !worldRoomPattern.MatchString(roomID) {
		http.Error(*w, "Invalid room", http.StatusBadRequest)
		return nil
	}

	conn, err := upgrader.Upgrade(*w, r, nil)
	if err != nil {
		l.Logger.Errorf("world ws upgrade: %v", err)
		return nil
	}

	sx, sy := worldPickSpawn(userID)

	worldRoomsMutex.Lock()
	room := worldRooms[roomID]
	if room == nil {
		room = make(map[string]*worldMember)
		worldRooms[roomID] = room
	}
	if old, exists := room[userID]; exists && old != nil && old.conn != nil {
		_ = old.conn.Close()
	}
	room[userID] = &worldMember{conn: conn, x: sx, y: sy}
	worldRoomsMutex.Unlock()

	peers := make([]map[string]interface{}, 0)
	worldRoomsMutex.RLock()
	if rmap, ok := worldRooms[roomID]; ok {
		for uid, m := range rmap {
			if uid == userID || m == nil {
				continue
			}
			peers = append(peers, map[string]interface{}{
				"user_id": uid,
				"x":       m.x,
				"y":       m.y,
			})
		}
	}
	worldRoomsMutex.RUnlock()

	if !worldSendJSON(conn, map[string]interface{}{
		"type":    "world_welcome",
		"user_id": userID,
		"room":    roomID,
		"x":       sx,
		"y":       sy,
		"peers":   peers,
	}) {
		worldLeaveRoom(roomID, userID)
		_ = conn.Close()
		return nil
	}

	worldBroadcast(roomID, userID, map[string]interface{}{
		"type":    "world_peer_joined",
		"user_id": userID,
		"x":       sx,
		"y":       sy,
	})

	go l.handleConnection(roomID, userID, conn)

	return nil
}

func (l *WorldWsLogic) handleConnection(roomID, userID string, conn *websocket.Conn) {
	defer func() {
		worldLeaveRoom(roomID, userID)
		_ = conn.Close()
		l.Logger.Infof("World ws user %s left room %s", userID, roomID)
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
				l.Logger.Errorf("World ws read: %v", err)
			}
			break
		}
		conn.SetReadDeadline(time.Now().Add(75 * time.Second))
		l.handleMessage(roomID, userID, conn, message)
	}
}

func (l *WorldWsLogic) handleMessage(roomID, userID string, conn *websocket.Conn, message []byte) {
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
		worldSendJSON(conn, map[string]interface{}{"type": "pong"})
	case "world_move":
		x, xok := toFloat(msg["x"])
		y, yok := toFloat(msg["y"])
		if !xok || !yok {
			return
		}
		worldRoomsMutex.Lock()
		if room, ok := worldRooms[roomID]; ok {
			if m, ok := room[userID]; ok && m != nil {
				m.x, m.y = x, y
			}
		}
		worldRoomsMutex.Unlock()
		worldBroadcast(roomID, userID, map[string]interface{}{
			"type":    "world_move",
			"user_id": userID,
			"x":       x,
			"y":       y,
		})
	default:
		l.Logger.Infof("World ws unknown type from %s: %s", userID, msgType)
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
