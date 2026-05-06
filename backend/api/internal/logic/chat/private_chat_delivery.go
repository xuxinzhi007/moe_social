package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"backend/api/internal/svc"
	"backend/rpc/pb/super"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/core/logx"
)

// NotificationTypePrivateChat 与 model.Notification.Type 一致：6=私信；WS 投递失败时写入通知表。
const NotificationTypePrivateChat = 6

// PeerUserIDFromChatMessage 解析 WS 私信目标用户 id（兼容 JSON 数字与 string）。
func PeerUserIDFromChatMessage(msg map[string]interface{}) (string, bool) {
	for _, key := range []string{"target_id", "to"} {
		if s, ok := stringifyJSONScalar(msg[key]); ok {
			return s, true
		}
	}
	return "", false
}

// NormalizeChatUserIDKey 将用户主键规范为十进制字符串（与 WS 注册键 fmt.Sprintf("%d", id) 对齐）。
func NormalizeChatUserIDKey(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return s
	}
	u, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		return s
	}
	return strconv.FormatUint(u, 10)
}

func stringifyJSONScalar(v interface{}) (string, bool) {
	if v == nil {
		return "", false
	}
	switch t := v.(type) {
	case string:
		s := strings.TrimSpace(t)
		if s == "" {
			return "", false
		}
		return s, true
	case float64:
		s := strconv.FormatFloat(t, 'f', 0, 64)
		if s == "" || s == "0" {
			return "", false
		}
		return s, true
	case json.Number:
		s := strings.TrimSpace(t.String())
		if s == "" {
			return "", false
		}
		return s, true
	default:
		s := strings.TrimSpace(fmt.Sprint(t))
		if s == "" || s == "<nil>" {
			return "", false
		}
		return s, true
	}
}

// PushJSONToChatUser 向已连接 /ws/chat 的用户推送一条 JSON（与原有 sendToUser 行为一致）。
func PushJSONToChatUser(userID string, data interface{}) bool {
	key := NormalizeChatUserIDKey(userID)
	chatConnectionsMutex.RLock()
	conn, ok := chatConnections[key]
	chatConnectionsMutex.RUnlock()
	if !ok {
		return false
	}
	msgData, err := json.Marshal(data)
	if err != nil {
		logx.Errorf("chat marshal to user=%s: %v", key, err)
		return false
	}
	err = conn.WriteMessage(websocket.TextMessage, msgData)
	if err != nil {
		logx.Errorf("chat write to user=%s: %v", key, err)
		chatConnectionsMutex.Lock()
		delete(chatConnections, key)
		chatConnectionsMutex.Unlock()
		_ = conn.Close()
		return false
	}
	return true
}

// ResolvePrivateMessageSenderProfile 私信投递时的展示名与头像：以服务端用户资料为准，不信任客户端 WS 里的 sender_name。
// 头像仅在调用方未传时由服务端补全。
func ResolvePrivateMessageSenderProfile(
	ctx context.Context,
	svc *svc.ServiceContext,
	senderID string,
	protoMsg *super.PrivateMessage,
	clientAvatar string,
) (senderName string, senderAvatar string) {
	senderAvatar = strings.TrimSpace(clientAvatar)
	senderName = ""
	var username string
	if svc != nil && svc.SuperRpcClient != nil {
		rpcResp, err := svc.SuperRpcClient.GetUser(ctx, &super.GetUserReq{UserId: senderID})
		if err == nil && rpcResp != nil && rpcResp.User != nil {
			u := rpcResp.User
			username = strings.TrimSpace(u.Username)
			if senderAvatar == "" {
				if av := strings.TrimSpace(u.Avatar); av != "" {
					senderAvatar = av
				}
			}
		}
	}
	if username != "" {
		senderName = username
	} else if protoMsg != nil {
		if m := strings.TrimSpace(protoMsg.SenderMoeNo); m != "" {
			senderName = m
		}
	}
	if senderName == "" {
		senderName = "用户"
	}
	return senderName, senderAvatar
}

// PersistOfflinePrivateChatNotification 对端无 WS 时写入通知中心（正文按字节截断，与旧逻辑一致）。
func PersistOfflinePrivateChatNotification(ctx context.Context, svc *svc.ServiceContext, targetUserID, fromUserID, content, senderName string) {
	body := strings.TrimSpace(content)
	if body == "" || targetUserID == fromUserID {
		return
	}
	if len(body) > 200 {
		body = body[:200]
	}
	if senderName != "" && senderName != "用户" {
		body = senderName + ": " + body
		if len(body) > 200 {
			body = body[:200]
		}
	}
	_, err := svc.SuperRpcClient.CreateNotification(ctx, &super.CreateNotificationReq{
		UserId:   targetUserID,
		SenderId: fromUserID,
		Type:     NotificationTypePrivateChat,
		PostId:   "",
		Content:  body,
	})
	if err != nil {
		logx.WithContext(ctx).Errorf("offline private chat notify to=%s from=%s: %v", targetUserID, fromUserID, err)
		return
	}
	logx.WithContext(ctx).Debugf("offline private chat notification to=%s from=%s", targetUserID, fromUserID)
}

// DeliverPrivateMessageRealTime 在私信已成功写入 RPC/DB 后：尝试 WS 推给接收方；失败则写通知兜底。
func DeliverPrivateMessageRealTime(ctx context.Context, svc *svc.ServiceContext, senderID, receiverID, content, senderName, senderAvatar string, protoMsg *super.PrivateMessage) {
	senderKey := NormalizeChatUserIDKey(senderID)
	recvKey := NormalizeChatUserIDKey(receiverID)
	now := time.Now()
	chatMsg := map[string]interface{}{
		"from":          senderKey,
		"content":       content,
		"time":          now.Format(time.RFC3339),
		"timestamp":     now.UnixMilli(),
		"sender_name":   senderName,
		"sender_avatar": senderAvatar,
		"senderName":    senderName,
		"senderAvatar":  senderAvatar,
	}
	if protoMsg != nil && protoMsg.Id != "" {
		chatMsg["server_message_id"] = protoMsg.Id
		chatMsg["expires_at"] = protoMsg.ExpiresAt
		if protoMsg.SenderMoeNo != "" {
			chatMsg["sender_moe_no"] = protoMsg.SenderMoeNo
		}
		if protoMsg.ReceiverMoeNo != "" {
			chatMsg["receiver_moe_no"] = protoMsg.ReceiverMoeNo
		}
	}
	if !PushJSONToChatUser(recvKey, chatMsg) {
		PersistOfflinePrivateChatNotification(ctx, svc, recvKey, senderKey, content, senderName)
	}
}
