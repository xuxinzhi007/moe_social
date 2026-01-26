package chat

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"backend/api/internal/chathub"
	"backend/api/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/core/logx"
)

// Old hub struct removed - now using chathub.DefaultHub via hubWrapper

// Use the shared chathub.DefaultHub instead of local instance
// Bridge local hub interface to shared DefaultHub
type hubWrapper struct{}

func (w *hubWrapper) addConn(userID string, conn *websocket.Conn) {
	chathub.DefaultHub.AddConn(userID, conn)
	broadcastPresence(userID, true)
}

func (w *hubWrapper) removeConn(userID string, conn *websocket.Conn) {
	chathub.DefaultHub.RemoveConn(userID, conn)
	broadcastPresence(userID, false)
}

func (w *hubWrapper) forwardMessage(fromID, toID, content string) {
	msg := serverMessage{
		From:      fromID,
		Content:   content,
		Timestamp: time.Now().UnixMilli(),
	}
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}

	toConn := chathub.DefaultHub.GetConn(toID)
	if toConn == nil {
		return
	}

	if err := toConn.WriteMessage(websocket.TextMessage, data); err != nil {
		logx.Errorf("write websocket message error: %v", err)
	}
}

func (w *hubWrapper) isOnline(userID string) bool {
	return chathub.DefaultHub.IsOnline(userID)
}

func (w *hubWrapper) onlineUserIDs() []string {
	return chathub.DefaultHub.OnlineUserIDs()
}

var chatHub = &hubWrapper{}

type remoteHub struct {
	mu    sync.RWMutex
	conns map[string][]*websocket.Conn
}

func newRemoteHub() *remoteHub {
	return &remoteHub{
		conns: make(map[string][]*websocket.Conn),
	}
}

var remoteWsHub = newRemoteHub()

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type clientMessage struct {
	Type    string `json:"type"`
	To      string `json:"to"`
	Content string `json:"content"`
}

type serverMessage struct {
	From      string `json:"from"`
	Content   string `json:"content"`
	Timestamp int64  `json:"timestamp"`
}

type presenceEvent struct {
	Type      string `json:"type"`
	UserID    string `json:"user_id"`
	Online    bool   `json:"online"`
	Timestamp int64  `json:"timestamp"`
}

type presenceSnapshot struct {
	Type          string   `json:"type"`
	OnlineUserIDs []string `json:"online_user_ids"`
	Timestamp     int64    `json:"timestamp"`
}

// Old hub methods removed - functionality now in hubWrapper above

// presence hub: broadcast presence events to all connected clients
type presenceHub struct {
	mu    sync.RWMutex
	conns map[string][]*websocket.Conn
}

func newPresenceHub() *presenceHub {
	return &presenceHub{conns: make(map[string][]*websocket.Conn)}
}

var presenceWsHub = newPresenceHub()

func (h *presenceHub) addConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.conns[userID] = append(h.conns[userID], conn)
}

func (h *presenceHub) removeConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	list, ok := h.conns[userID]
	if !ok {
		return
	}
	n := 0
	for _, c := range list {
		if c == nil || c == conn {
			continue
		}
		list[n] = c
		n++
	}
	if n == 0 {
		delete(h.conns, userID)
		return
	}
	h.conns[userID] = list[:n]
}

func (h *presenceHub) broadcastAll(data []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, list := range h.conns {
		for _, c := range list {
			if c == nil {
				continue
			}
			if err := c.WriteMessage(websocket.TextMessage, data); err != nil {
				logx.Errorf("write presence websocket message error: %v", err)
			}
		}
	}
}

func broadcastPresence(userID string, online bool) {
	evt := presenceEvent{
		Type:      "presence",
		UserID:    userID,
		Online:    online,
		Timestamp: time.Now().UnixMilli(),
	}
	data, err := json.Marshal(evt)
	if err != nil {
		return
	}
	presenceWsHub.broadcastAll(data)
}

func (h *remoteHub) addConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	list := h.conns[userID]
	h.conns[userID] = append(list, conn)
}

func (h *remoteHub) removeConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	list, ok := h.conns[userID]
	if !ok {
		return
	}
	n := 0
	for _, c := range list {
		if c == nil || c == conn {
			continue
		}
		list[n] = c
		n++
	}
	if n == 0 {
		delete(h.conns, userID)
		return
	}
	h.conns[userID] = list[:n]
}

func (h *remoteHub) broadcast(userID string, data []byte) {
	h.mu.RLock()
	list := h.conns[userID]
	h.mu.RUnlock()
	for _, c := range list {
		if c == nil {
			continue
		}
		if err := c.WriteMessage(websocket.TextMessage, data); err != nil {
			logx.Errorf("write remote websocket message error: %v", err)
		}
	}
}

func ChatWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := ""

		queryToken := r.URL.Query().Get("token")
		if queryToken != "" {
			token = queryToken
		} else {
			authHeader := r.Header.Get("Authorization")
			if strings.HasPrefix(authHeader, "Bearer ") {
				token = strings.TrimPrefix(authHeader, "Bearer ")
			}
		}

		if token == "" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		userIDUint, err := utils.GetUserIDFromToken(token)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		userID := strconv.Itoa(int(userIDUint))

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			logx.Errorf("upgrade websocket error: %v", err)
			return
		}

		chatHub.addConn(userID, conn)

		go func(uid string, c *websocket.Conn) {
			defer func() {
				chatHub.removeConn(uid, c)
				c.Close()
			}()

			for {
				_, data, err := c.ReadMessage()
				if err != nil {
					break
				}

				var msg clientMessage
				if err := json.Unmarshal(data, &msg); err != nil {
					continue
				}

				if msg.Type != "message" {
					continue
				}
				if msg.To == "" || msg.Content == "" {
					continue
				}

				chatHub.forwardMessage(uid, msg.To, msg.Content)

				content := msg.Content
				if len(content) > 100 {
					content = content[:100]
				}

				_, err = svcCtx.SuperRpcClient.CreateNotification(context.Background(), &super.CreateNotificationReq{
					UserId:   msg.To,
					SenderId: uid,
					Type:     6,
					PostId:   "",
					Content:  content,
				})
				if err != nil {
					logx.Errorf("create direct message notification error: %v", err)
				}
			}
		}(userID, conn)
	}
}

func RemoteWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := ""

		queryToken := r.URL.Query().Get("token")
		if queryToken != "" {
			token = queryToken
		} else {
			authHeader := r.Header.Get("Authorization")
			if strings.HasPrefix(authHeader, "Bearer ") {
				token = strings.TrimPrefix(authHeader, "Bearer ")
			}
		}

		if token == "" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		userIDUint, err := utils.GetUserIDFromToken(token)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		userID := strconv.Itoa(int(userIDUint))

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			logx.Errorf("upgrade remote websocket error: %v", err)
			return
		}

		remoteWsHub.addConn(userID, conn)

		go func(uid string, c *websocket.Conn) {
			defer func() {
				remoteWsHub.removeConn(uid, c)
				c.Close()
			}()

			for {
				_, data, err := c.ReadMessage()
				if err != nil {
					break
				}
				remoteWsHub.broadcast(uid, data)
			}
		}(userID, conn)
	}
}

// PresenceWsHandler provides push-based online status updates.
// Client connects with token (query or Authorization header).
// Server sends a snapshot first, then broadcasts presence events.
func PresenceWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx

	return func(w http.ResponseWriter, r *http.Request) {
		token := ""
		queryToken := r.URL.Query().Get("token")
		if queryToken != "" {
			token = queryToken
		} else {
			authHeader := r.Header.Get("Authorization")
			if strings.HasPrefix(authHeader, "Bearer ") {
				token = strings.TrimPrefix(authHeader, "Bearer ")
			}
		}
		if token == "" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		userIDUint, err := utils.GetUserIDFromToken(token)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		userID := strconv.Itoa(int(userIDUint))

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			logx.Errorf("upgrade presence websocket error: %v", err)
			return
		}

		presenceWsHub.addConn(userID, conn)

		// send snapshot
		snapshot := presenceSnapshot{
			Type:          "presence_snapshot",
			OnlineUserIDs: chatHub.onlineUserIDs(),
			Timestamp:     time.Now().UnixMilli(),
		}
		if data, err := json.Marshal(snapshot); err == nil {
			_ = conn.WriteMessage(websocket.TextMessage, data)
		}

		go func(uid string, c *websocket.Conn) {
			defer func() {
				presenceWsHub.removeConn(uid, c)
				c.Close()
			}()

			for {
				// keep connection alive; server does not require client messages
				if _, _, err := c.ReadMessage(); err != nil {
					break
				}
			}
		}(userID, conn)
	}
}

// GetChatOnlineStatus 供 logic 层调用，查询单个用户在线状态
func GetChatOnlineStatus(userID string) bool {
	return chatHub.isOnline(userID)
}

// GetChatOnlineBatch 供 logic 层调用，批量查询用户在线状态
func GetChatOnlineBatch(userIDs []string) map[string]bool {
	online := make(map[string]bool, len(userIDs))
	for _, id := range userIDs {
		if id == "" {
			continue
		}
		online[id] = chatHub.isOnline(id)
	}
	return online
}
