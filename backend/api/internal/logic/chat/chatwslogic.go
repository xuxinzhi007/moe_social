package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"backend/api/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/core/logx"
)

// 全局聊天连接映射
var (
	chatConnections      = make(map[string]*websocket.Conn)
	chatConnectionsMutex sync.RWMutex
)

// 聊天消息结构
type ChatMessage struct {
	From    string `json:"from"`
	Content string `json:"content"`
	Time    string `json:"time"`
}

type ChatWsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// WebSocket聊天服务
func NewChatWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatWsLogic {
	return &ChatWsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatWsLogic) ChatWs() error {
	// 从上下文获取 HTTP 请求
	r, ok := l.ctx.Value("http.Request").(*http.Request)
	if !ok {
		return nil
	}

	w, ok := l.ctx.Value("http.ResponseWriter").(*http.ResponseWriter)
	if !ok {
		return nil
	}

	// 验证 token
	token := r.Header.Get("Authorization")
	if token == "" {
		// 尝试从查询参数获取 token
		token = r.URL.Query().Get("token")
		if token == "" {
			http.Error(*w, "Unauthorized", http.StatusUnauthorized)
			return nil
		}
	} else {
		// 处理 Bearer token
		if strings.HasPrefix(token, "Bearer ") {
			token = strings.TrimPrefix(token, "Bearer ")
		}
	}

	// 验证 token
	claims, err := utils.ParseToken(token)
	if err != nil {
		http.Error(*w, "Invalid token", http.StatusUnauthorized)
		return nil
	}

	// 获取用户 ID（与投递时 NormalizeChatUserIDKey 对齐）
	userID := NormalizeChatUserIDKey(fmt.Sprintf("%d", claims.UserID))

	// 升级 HTTP 连接为 WebSocket
	conn, err := upgrader.Upgrade(*w, r, nil)
	if err != nil {
		l.Logger.Errorf("Error upgrading connection: %v", err)
		return nil
	}

	// 存储用户连接
	chatConnectionsMutex.Lock()
	chatConnections[userID] = conn
	chatConnectionsMutex.Unlock()
	l.Logger.Infof("Chat user %s connected", userID)

	// 处理消息
	go l.handleConnection(userID, conn)

	return nil
}

// 处理 WebSocket 连接
func (l *ChatWsLogic) handleConnection(userID string, conn *websocket.Conn) {
	defer func() {
		TryMatchCancel(userID)
		chatConnectionsMutex.Lock()
		delete(chatConnections, userID)
		chatConnectionsMutex.Unlock()
		conn.Close()
		l.Logger.Infof("Chat user %s disconnected", userID)
	}()

	// 设置读取超时
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				l.Logger.Errorf("WebSocket error: %v", err)
			}
			break
		}
		logx.WithContext(l.ctx).Debugf("chat ws raw from %s len=%d", userID, len(message))
		// 处理前端发送的消息
		l.handleMessage(userID, message)
	}
}

// 处理前端发送的消息
func (l *ChatWsLogic) handleMessage(userID string, message []byte) {
	// 解析消息
	var msg map[string]interface{}
	if err := json.Unmarshal(message, &msg); err != nil {
		l.Logger.Errorf("Error unmarshaling message: %v", err)
		return
	}

	// 根据消息类型处理
	msgType, ok := msg["type"].(string)
	if !ok {
		l.Logger.Errorf("Invalid message type")
		return
	}
	logx.WithContext(l.ctx).Debugf("chat ws message from %s type=%s", userID, msgType)

	switch msgType {
	case "ping":
		// 响应 ping
		l.sendToUser(userID, map[string]interface{}{
			"type": "pong",
		})
	case "match_join":
		TryMatchJoin(userID, l.sendToUser)
	case "match_cancel":
		TryMatchCancel(userID)
		l.sendToUser(userID, map[string]interface{}{
			"type": "match_cancelled",
		})
	case "message":
		// 处理聊天消息
		l.handleChatMessage(userID, msg)
	default:
		logx.WithContext(l.ctx).Debugf("chat ws unknown type from %s: %s", userID, msgType)
	}
}

// 处理聊天消息
func (l *ChatWsLogic) handleChatMessage(userID string, msg map[string]interface{}) {
	// 提取消息内容
	content, ok := msg["content"].(string)
	if !ok {
		l.Logger.Errorf("Invalid message content")
		return
	}

	targetID, ok := PeerUserIDFromChatMessage(msg)
	if !ok {
		l.Logger.Errorf("Invalid target ID: neither 'target_id' nor 'to' (string/number)")
		return
	}

	// 头像可来自客户端；展示名在落库成功后一律由服务端解析（与 REST 发送路径一致）。
	senderAvatar := ""
	if avatar, ok := msg["sender_avatar"].(string); ok && avatar != "" {
		senderAvatar = avatar
	} else if avatar, ok := msg["senderAvatar"].(string); ok && avatar != "" {
		senderAvatar = avatar
	}

	logx.WithContext(l.ctx).Debugf("chat ws send from=%s to=%s", userID, targetID)

	paths := extractImagePathsFromWSMsg(msg)
	rpcResp, rpcErr := l.svcCtx.SuperRpcClient.SendPrivateMessage(l.ctx, &super.SendPrivateMessageReq{
		SenderId:    userID,
		ReceiverId:  targetID,
		Body:        content,
		ImagePaths:  paths,
	})
	if rpcErr != nil {
		l.Errorf("SendPrivateMessage (ws path): %v", rpcErr)
	}
	if rpcErr != nil || rpcResp == nil || rpcResp.Message == nil || strings.TrimSpace(rpcResp.Message.Id) == "" {
		_ = l.sendToUser(userID, map[string]interface{}{
			"type":    "private_message_error",
			"message": "消息保存失败，请检查网络或稍后重试",
		})
		return
	}

	senderName, senderAvatar := ResolvePrivateMessageSenderProfile(
		l.ctx, l.svcCtx, userID, rpcResp.Message, senderAvatar,
	)
	DeliverPrivateMessageRealTime(l.ctx, l.svcCtx, userID, targetID, content, senderName, senderAvatar, rpcResp.Message)
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

// 发送消息给指定用户
func (l *ChatWsLogic) sendToUser(userID string, data interface{}) bool {
	return PushJSONToChatUser(userID, data)
}
