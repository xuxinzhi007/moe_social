package chatbiz

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"backend/internal/pkg/presence"
	"backend/utils"

	"github.com/gorilla/websocket"
	"backend/internal/platform/moelog"
)

var (
	presenceConnections      = make(map[string]*presenceConn)
	presenceConnectionsMutex sync.RWMutex
)

type presenceConn struct {
	writeMu sync.Mutex
	conn    *websocket.Conn
}

func (pc *presenceConn) writeJSON(data interface{}) bool {
	if pc == nil {
		return false
	}
	msgData, err := json.Marshal(data)
	if err != nil {
		return false
	}
	return pc.writeText(msgData)
}

func (pc *presenceConn) writeText(msgData []byte) bool {
	if pc == nil {
		return false
	}
	pc.writeMu.Lock()
	defer pc.writeMu.Unlock()
	if pc.conn == nil {
		return false
	}
	_ = pc.conn.SetWriteDeadline(time.Now().Add(8 * time.Second))
	if err := pc.conn.WriteMessage(websocket.TextMessage, msgData); err != nil {
		return false
	}
	return true
}

func (pc *presenceConn) close() {
	if pc == nil {
		return
	}
	pc.writeMu.Lock()
	defer pc.writeMu.Unlock()
	if pc.conn != nil {
		_ = pc.conn.Close()
		pc.conn = nil
	}
}

// PresenceMessage 在线状态 WS 消息。
type PresenceMessage struct {
	Type          string   `json:"type"`
	UserID        string   `json:"user_id,omitempty"`
	Online        bool     `json:"online,omitempty"`
	OnlineUserIDs []string `json:"online_user_ids,omitempty"`
}

// ServePresenceWS 升级 /ws/presence 连接（tier-A 入口）。
func ServePresenceWS(w http.ResponseWriter, r *http.Request) {
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

	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		moelog.Errorf("presence ws upgrade: %v", err)
		return
	}

	member := &presenceConn{conn: conn}

	presenceConnectionsMutex.Lock()
	if old, exists := presenceConnections[userID]; exists && old != nil {
		old.close()
	}
	presenceConnections[userID] = member
	presenceConnectionsMutex.Unlock()

	becameOnline := presence.DefaultState.Add(userID)
	moelog.Infof("Presence user %s connected", userID)

	sendPresenceSnapshot(userID)

	if becameOnline {
		broadcastPresence(userID, true)
	}

	go handlePresenceWSLoop(userID, member)
}

func handlePresenceWSLoop(userID string, member *presenceConn) {
	defer func() {
		var becameOffline bool
		presenceConnectionsMutex.Lock()
		if current, ok := presenceConnections[userID]; ok && current == member {
			delete(presenceConnections, userID)
			becameOffline = presence.DefaultState.Remove(userID)
		}
		presenceConnectionsMutex.Unlock()

		member.close()
		moelog.Infof("Presence user %s disconnected", userID)

		if becameOffline {
			broadcastPresence(userID, false)
		}
	}()

	if member.conn == nil {
		return
	}

	_ = member.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	member.conn.SetPongHandler(func(string) error {
		if member.conn != nil {
			_ = member.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		}
		return nil
	})

	for {
		if member.conn == nil {
			break
		}
		_, message, err := member.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				moelog.Errorf("presence ws error: %v", err)
			}
			break
		}
		handlePresenceWSMessage(userID, message)
	}
}

func handlePresenceWSMessage(userID string, message []byte) {
	var msg map[string]interface{}
	if err := json.Unmarshal(message, &msg); err != nil {
		moelog.Errorf("presence ws unmarshal: %v", err)
		return
	}
	msgType, ok := msg["type"].(string)
	if !ok {
		return
	}

	switch msgType {
	case "ping":
		presenceSendToUser(userID, map[string]interface{}{"type": "pong"})
	case "get_online":
		sendPresenceSnapshot(userID)
	}
}

func sendPresenceSnapshot(userID string) {
	userIDs := presence.DefaultState.OnlineUserIDs()
	presenceSendToUser(userID, PresenceMessage{
		Type:          "presence_snapshot",
		OnlineUserIDs: userIDs,
	})
}

func broadcastPresence(userID string, online bool) {
	message := PresenceMessage{
		Type:   "presence",
		UserID: userID,
		Online: online,
	}
	msgData, err := json.Marshal(message)
	if err != nil {
		moelog.Errorf("presence broadcast marshal: %v", err)
		return
	}

	presenceConnectionsMutex.RLock()
	recipients := make([]*presenceConn, 0, len(presenceConnections))
	for id, pc := range presenceConnections {
		if id == userID || pc == nil {
			continue
		}
		recipients = append(recipients, pc)
	}
	presenceConnectionsMutex.RUnlock()

	for _, pc := range recipients {
		if !pc.writeText(msgData) {
			moelog.Errorf("presence broadcast write failed")
		}
	}
}

func presenceSendToUser(userID string, data interface{}) bool {
	presenceConnectionsMutex.RLock()
	pc, ok := presenceConnections[userID]
	presenceConnectionsMutex.RUnlock()

	if !ok || pc == nil {
		return false
	}
	if !pc.writeJSON(data) {
		presenceConnectionsMutex.Lock()
		if current, exists := presenceConnections[userID]; exists && current == pc {
			delete(presenceConnections, userID)
		}
		presenceConnectionsMutex.Unlock()
		pc.close()
		return false
	}
	return true
}

// OnlineUserIDSet 返回当前在线用户 id 集合（供 REST /api/chat/online 等使用）。
func OnlineUserIDSet() map[string]bool {
	result := make(map[string]bool)
	for _, id := range presence.DefaultState.OnlineUserIDs() {
		result[id] = true
	}
	return result
}
