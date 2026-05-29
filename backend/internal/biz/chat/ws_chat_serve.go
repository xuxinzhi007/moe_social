package chatbiz

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	chatv1 "backend/api/chat/v1"
	"backend/utils"

	"backend/internal/platform/moelog"
	"github.com/gorilla/websocket"
)

// PrivateMessageSender 私信持久化（ChatApp 或进程内适配器）。
type PrivateMessageSender interface {
	SendPrivateMessage(ctx context.Context, in *chatv1.SendPrivateMessageRequest) (*chatv1.SendPrivateMessageReply, error)
}

// ChatWSDeps /ws/chat 业务依赖。
type ChatWSDeps struct {
	PM       PrivateMessageSender
	Delivery DeliveryDeps
}

// ServeChatWS 升级 /ws/chat 连接（tier-A 入口）。
func ServeChatWS(w http.ResponseWriter, r *http.Request, ctx context.Context, deps ChatWSDeps) {
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
	userID := NormalizeChatUserIDKey(fmt.Sprintf("%d", claims.UserID))

	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		moelog.Errorf("chat ws upgrade: %v", err)
		return
	}

	RegisterChatWSConnection(userID, conn)
	moelog.Infof("Chat user %s connected", userID)
	go handleChatWSLoop(ctx, userID, conn, deps)
}

func handleChatWSLoop(ctx context.Context, userID string, conn *websocket.Conn, deps ChatWSDeps) {
	defer func() {
		TryMatchCancel(userID)
		UnregisterChatWSConnection(userID)
		_ = conn.Close()
		moelog.Infof("Chat user %s disconnected", userID)
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
				moelog.Errorf("chat ws error: %v", err)
			}
			break
		}
		moelog.WithContext(ctx).Debugf("chat ws raw from %s len=%d", userID, len(message))
		handleChatWSMessage(ctx, userID, message, deps)
	}
}

func handleChatWSMessage(ctx context.Context, userID string, message []byte, deps ChatWSDeps) {
	var msg map[string]interface{}
	if err := json.Unmarshal(message, &msg); err != nil {
		moelog.Errorf("chat ws unmarshal: %v", err)
		return
	}
	msgType, ok := msg["type"].(string)
	if !ok {
		moelog.Errorf("chat ws invalid message type")
		return
	}
	moelog.WithContext(ctx).Debugf("chat ws message from %s type=%s", userID, msgType)

	send := func(uid string, data interface{}) bool {
		return PushJSONToChatUser(uid, data)
	}

	switch msgType {
	case "ping":
		send(userID, map[string]interface{}{"type": "pong"})
	case "match_join":
		TryMatchJoin(userID, send)
	case "match_cancel":
		TryMatchCancel(userID)
		send(userID, map[string]interface{}{"type": "match_cancelled"})
	case "message":
		handleChatWSPrivateMessage(ctx, userID, msg, deps, send)
	default:
		moelog.WithContext(ctx).Debugf("chat ws unknown type from %s: %s", userID, msgType)
	}
}

func handleChatWSPrivateMessage(
	ctx context.Context,
	userID string,
	msg map[string]interface{},
	deps ChatWSDeps,
	send func(string, interface{}) bool,
) {
	content, ok := msg["content"].(string)
	if !ok {
		moelog.Errorf("chat ws invalid message content")
		return
	}
	targetID, ok := PeerUserIDFromChatMessage(msg)
	if !ok {
		moelog.Errorf("chat ws invalid target id")
		return
	}

	senderAvatar := ""
	if avatar, ok := msg["sender_avatar"].(string); ok && avatar != "" {
		senderAvatar = avatar
	} else if avatar, ok := msg["senderAvatar"].(string); ok && avatar != "" {
		senderAvatar = avatar
	}

	moelog.WithContext(ctx).Debugf("chat ws send from=%s to=%s", userID, targetID)

	if deps.PM == nil {
		_ = send(userID, map[string]interface{}{
			"type":    "private_message_error",
			"message": "消息保存失败，请检查网络或稍后重试",
		})
		return
	}

	rpcResp, rpcErr := deps.PM.SendPrivateMessage(ctx, &chatv1.SendPrivateMessageRequest{
		SenderId:   userID,
		ReceiverId: targetID,
		Body:       content,
		ImagePaths: extractImagePathsFromWSMsg(msg),
	})
	if rpcErr != nil {
		moelog.Errorf("SendPrivateMessage (ws path): %v", rpcErr)
	}
	if rpcErr != nil || rpcResp == nil || rpcResp.Message == nil || strings.TrimSpace(rpcResp.Message.Id) == "" {
		_ = send(userID, map[string]interface{}{
			"type":    "private_message_error",
			"message": "消息保存失败，请检查网络或稍后重试",
		})
		return
	}

	senderName, senderAvatar := ResolvePrivateMessageSenderProfile(
		ctx, deps.Delivery, userID, rpcResp.Message, senderAvatar,
	)
	DeliverPrivateMessageRealTime(ctx, deps.Delivery, userID, targetID, content, senderName, senderAvatar, rpcResp.Message)
}

func extractImagePathsFromWSMsg(msg map[string]interface{}) []string {
	v, ok := msg["image_paths"]
	if !ok {
		v, ok = msg["imagePaths"]
	}
	if !ok {
		return nil
	}
	arr, ok := v.([]interface{})
	if !ok {
		return nil
	}
	out := make([]string, 0, len(arr))
	for _, x := range arr {
		if s, ok := x.(string); ok && s != "" {
			out = append(out, s)
		}
	}
	return out
}
