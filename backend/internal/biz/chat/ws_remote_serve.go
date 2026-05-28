package chatbiz

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"backend/utils"

	"github.com/gorilla/websocket"
	"backend/internal/platform/moelog"
)

var wsUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// ServeRemoteWS 升级 /ws/remote 连接（tier-A 入口）。
func ServeRemoteWS(w http.ResponseWriter, r *http.Request) {
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
		moelog.Errorf("remote ws upgrade: %v", err)
		return
	}
	RegisterWSConnection(userID, conn)
	moelog.Infof("remote ws user %s connected", userID)
	go handleRemoteWSLoop(userID, conn)
}

func extractWSToken(r *http.Request) string {
	token := r.Header.Get("Authorization")
	if token == "" {
		return strings.TrimSpace(r.URL.Query().Get("token"))
	}
	if strings.HasPrefix(token, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(token, "Bearer "))
	}
	return strings.TrimSpace(token)
}

func handleRemoteWSLoop(userID string, conn *websocket.Conn) {
	defer func() {
		UnregisterWSConnection(userID)
		_ = conn.Close()
		moelog.Infof("remote ws user %s disconnected", userID)
	}()
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})
	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				moelog.Errorf("remote ws error: %v", err)
			}
			break
		}
		handleRemoteWSMessage(userID, message)
	}
}

func handleRemoteWSMessage(userID string, message []byte) {
	var msg map[string]interface{}
	if err := json.Unmarshal(message, &msg); err != nil {
		moelog.Errorf("remote ws unmarshal: %v", err)
		return
	}
	msgType, _ := msg["type"].(string)
	if msgType == "ping" {
		_ = SendRawToUser(userID, map[string]interface{}{"type": "pong"})
	}
}
