package chat

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"backend/api/internal/svc"
	"backend/utils"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/core/logx"
)

type hub struct {
	mu    sync.RWMutex
	conns map[string]*websocket.Conn
}

func newHub() *hub {
	return &hub{
		conns: make(map[string]*websocket.Conn),
	}
}

var chatHub = newHub()

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

func (h *hub) addConn(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if old, ok := h.conns[userID]; ok && old != conn {
		old.Close()
	}
	h.conns[userID] = conn
}

func (h *hub) removeConn(userID string, conn *websocket.Conn) {
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

func (h *hub) forwardMessage(fromID, toID, content string) {
	msg := serverMessage{
		From:      fromID,
		Content:   content,
		Timestamp: time.Now().UnixMilli(),
	}
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}

	h.mu.RLock()
	toConn, ok := h.conns[toID]
	h.mu.RUnlock()
	if !ok || toConn == nil {
		return
	}

	if err := toConn.WriteMessage(websocket.TextMessage, data); err != nil {
		logx.Errorf("write websocket message error: %v", err)
	}
}

func ChatWsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
			}
		}(userID, conn)
	}
}

