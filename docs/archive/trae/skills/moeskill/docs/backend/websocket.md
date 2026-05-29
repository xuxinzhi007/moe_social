# WebSocket 实时通信实现

## 项目实际 WebSocket 服务（必读）

项目前端有两个 WebSocket 服务，均在 `lib/services/` 目录：

| 服务 | 路径 | 作用 |
|------|------|------|
| `ChatPushService` | `/ws/chat` | 私信推送、未读消息数（`unreadBySender` Map） |
| `PresenceService` | `/ws/presence` | 在线状态（`online` ValueNotifier） |

### 正确的启动 / 停止时机

```dart
// ✅ 登录成功后启动
AuthService.login(...);
PresenceService.start();
ChatPushService.start();

// ✅ 注销时停止（防止重连风暴）
PresenceService.stop();
ChatPushService.stop();

// ✅ App 启动时，若已登录则立即启动（main.dart）
if (AuthService.isLoggedIn) {
  PresenceService.start();
  ChatPushService.start();
}

// ✅ Token 刷新后重新启动（auth_service.dart updateToken）
AuthService.updateToken(newToken);
// 内部会自动调用 PresenceService.start() / ChatPushService.start()
```

### 401 自动登出

`ChatPushService` 有一个 `onAuthError` 回调，在 WebSocket 收到 401 时触发。`AuthService.init()` 中已配置：

```dart
ChatPushService.onAuthError = () { AuthService.logout(); };
```

**不要在其他地方重复设置**，会覆盖已有配置导致未预期行为。

### Web 平台特殊处理

`NotificationProvider` 在 Web 端页面进入 `paused`/`inactive` 时**不停止** ChatPushService / PresenceService，避免浏览器路由切换误判为离线。Mobile 端遵循正常 App 生命周期。

### 读取在线状态和未读消息数

```dart
// 在线状态（ValueNotifier，可用 ValueListenableBuilder）
PresenceService.online.value  // bool

// 某个用户的未读消息数
ChatPushService.unreadBySender[userId] ?? 0
```

---

## 概述

Moe Social项目使用WebSocket实现实时通信功能，包括在线状态管理、实时消息推送、聊天功能等。本指南将详细介绍如何在项目中实现WebSocket通信。

## 技术栈

- **后端**：Go语言 + go-zero框架
- **WebSocket库**：gorilla/websocket
- **前端**：Flutter + web_socket_channel

## 后端实现

### 依赖安装

```bash
go get github.com/gorilla/websocket
```

### WebSocket处理器

在`backend/api/internal/handler/chat/wshandler.go`中实现WebSocket处理器：

```go
package chat

import (
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/rest/httpx"
	"moe_social/backend/api/internal/logic/chat"
	"moe_social/backend/api/internal/svc"
	"moe_social/backend/api/internal/types"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // 生产环境中应该设置更严格的检查
	},
}

func WsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("Failed to upgrade connection: %v", err)
			return
		}
		defer conn.Close()

		// 创建WebSocket逻辑处理器
		logic := chat.NewChatWsLogic(r.Context(), svcCtx)
		logic.Handle(conn)
	}
}
```

### WebSocket逻辑

在`backend/api/internal/logic/chat/chatwslogic.go`中实现WebSocket逻辑：

```go
package chat

import (
	"context"
	"log"
	"time"

	"github.com/gorilla/websocket"
	"moe_social/backend/api/internal/svc"
	"moe_social/backend/api/internal/types"
)

const (
	// 写入超时时间
	writeWait = 10 * time.Second

	// 读取超时时间
	pongWait = 60 * time.Second

	// 发送ping的间隔时间，必须小于pongWait
	pingPeriod = (pongWait * 9) / 10

	// 最大消息大小
	maxMessageSize = 512
)

type ChatWsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewChatWsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatWsLogic {
	return &ChatWsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatWsLogic) Handle(conn *websocket.Conn) {
	// 设置连接参数
	conn.SetReadLimit(maxMessageSize)
	conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	// 启动goroutine处理消息读取
	go l.readPump(conn)

	// 启动goroutine处理消息写入
	go l.writePump(conn)

	// 等待连接关闭
	<-l.ctx.Done()
}

func (l *ChatWsLogic) readPump(conn *websocket.Conn) {
	defer func() {
		// 清理连接
		conn.Close()
	}()

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
			}
			break
		}

		// 处理接收到的消息
		l.handleMessage(message, conn)
	}
}

func (l *ChatWsLogic) writePump(conn *websocket.Conn) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		conn.Close()
	}()

	for {
		select {
		case <-ticker.C:
			conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (l *ChatWsLogic) handleMessage(message []byte, conn *websocket.Conn) {
	// 解析消息
	var msg types.ChatMessage
	// 处理消息逻辑
	// ...

	// 回复消息
	response := types.ChatResponse{
		Type:    "message",
		Content: "Message received",
	}
	conn.WriteJSON(response)
}
```

### 连接管理

在`backend/api/internal/chathub/hub.go`中实现连接管理：

```go
package chathub

import (
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// Hub 维护活动客户端的集合并向客户端广播消息
type Hub struct {
	// 注册的客户端
	clients map[*Client]bool

	// 从客户端入站的消息
	broadcast chan []byte

	// 注册请求
	register chan *Client

	// 注销请求
	unregister chan *Client

	// 互斥锁
	mu sync.Mutex
}

// Client 是WebSocket连接的中间人
type Client struct {
	hub  *Hub
	conn *websocket.Conn
	send chan []byte
	userID uint
}

func NewHub() *Hub {
	return &Hub{
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		clients:    make(map[*Client]bool),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Printf("Client registered: %d", client.userID)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				log.Printf("Client unregistered: %d", client.userID)
			}
			h.mu.Unlock()

		case message := <-h.broadcast:
			h.mu.Lock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.Unlock()
		}
	}
}

// 向特定用户发送消息
func (h *Hub) SendToUser(userID uint, message []byte) {
	h.mu.Lock()
	defer h.mu.Unlock()

	for client := range h.clients {
		if client.userID == userID {
			select {
			case client.send <- message:
			default:
				close(client.send)
				delete(h.clients, client)
			}
		}
	}
}
```

## 前端实现

### 依赖添加

在`pubspec.yaml`中添加依赖：

```yaml
dependencies:
  web_socket_channel: ^2.4.0
```

### WebSocket服务

在`lib/services/ws_channel_connector.dart`中实现WebSocket连接：

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WSChannelConnector {
  static WebSocketChannel? _channel;
  static bool _isConnected = false;

  static Future<void> connect(String url) async {
    try {
      _channel = IOWebSocketChannel.connect(url);
      _isConnected = true;
      print('WebSocket connected');
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
    }
  }

  static void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _isConnected = false;
      print('WebSocket disconnected');
    }
  }

  static bool get isConnected => _isConnected;

  static WebSocketChannel? get channel => _channel;

  static void sendMessage(dynamic message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(message);
    }
  }
}
```

### 聊天页面示例

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:moe_social/services/ws_channel_connector.dart';

class ChatPage extends StatefulWidget {
  final String userId;
  
  const ChatPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    WSChannelConnector.connect('ws://localhost:8080/ws?user_id=${widget.userId}');
    
    if (WSChannelConnector.channel != null) {
      WSChannelConnector.channel!.stream.listen(
        (message) {
          setState(() {
            _messages.add(jsonDecode(message));
          });
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket connection closed');
        },
      );
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final message = {
        'type': 'chat',
        'content': _controller.text,
        'user_id': widget.userId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      WSChannelConnector.sendMessage(jsonEncode(message));
      _controller.clear();
    }
  }

  @override
  void dispose() {
    WSChannelConnector.disconnect();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ListTile(
                  title: Text(message['content']),
                  subtitle: Text(message['timestamp']),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(labelText: 'Enter message'),
                  ),
                ),
                ElevatedButton(
                  onPressed: _sendMessage,
                  child: Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## 实时状态管理

### 在线状态

使用WebSocket实现用户在线状态管理：

1. **用户上线**：建立WebSocket连接时，更新用户状态为在线
2. **用户下线**：WebSocket连接关闭时，更新用户状态为离线
3. **状态广播**：向其他用户广播状态变更

### 实现示例

```go
// 更新用户在线状态
func (l *ChatWsLogic) updateUserStatus(userID uint, isOnline bool) {
	// 更新数据库中的用户状态
	// ...

	// 广播状态变更
	statusMessage := types.StatusUpdate{
		UserID:   userID,
		IsOnline: isOnline,
		Timestamp: time.Now().Unix(),
	}
	message, _ := json.Marshal(statusMessage)
	l.svcCtx.Hub.broadcast <- message
}
```

## 性能优化

### 后端优化

1. **连接池管理**：限制同时在线连接数
2. **消息队列**：使用消息队列处理高并发消息
3. **内存管理**：及时清理无效连接
4. **负载均衡**：使用负载均衡分散WebSocket连接

### 前端优化

1. **重连机制**：实现自动重连功能
2. **消息缓存**：本地缓存消息，减少网络请求
3. **批处理**：合并多个消息为一个批次发送
4. **心跳检测**：定期发送心跳包保持连接

## 安全措施

1. **认证**：WebSocket连接时进行用户认证
2. **授权**：验证用户权限
3. **数据加密**：使用WSS协议加密传输
4. **速率限制**：防止DoS攻击
5. **消息验证**：验证消息格式和内容

## 常见问题

### 连接断开

- **原因**：网络不稳定、服务器重启、超时
- **解决方案**：实现自动重连机制，设置合理的心跳间隔

### 消息丢失

- **原因**：网络中断、服务器崩溃
- **解决方案**：实现消息确认机制，使用消息队列

### 性能问题

- **原因**：连接数过多、消息处理慢
- **解决方案**：优化代码，使用负载均衡，增加服务器资源

## 总结

WebSocket为Moe Social项目提供了实时通信能力，使得在线状态管理、实时消息推送、聊天功能等得以实现。通过合理的架构设计和性能优化，可以构建稳定、高效的实时通信系统。

在实际开发中，应根据项目需求和用户规模，选择合适的WebSocket实现方案，并不断优化系统性能，确保用户体验。