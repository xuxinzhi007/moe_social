# WebSocket 推送通知功能对接文档

## 1. 概述

本文档详细说明如何实现基于 WebSocket 的推送通知功能，用于替代 Firebase 推送通知。该功能主要用于实现语音通话的来电通知，以及其他实时通知。

## 2. 前端实现

### 2.1 连接管理

- 前端在用户登录后自动建立 WebSocket 连接
- 连接地址：`ws://{base_url}/ws/remote`（根据环境自动切换 ws/wss）
- 连接时会在请求头中携带 `Authorization: Bearer {token}` 进行认证

### 2.2 消息处理

- 前端接收后端发送的 WebSocket 消息
- 当接收到类型为 `notification` 的消息时，会调用 `PushNotificationService.handleWebSocketNotification` 处理
- 对于来电通知（`type: 'incoming_call'`），会导航到来电页面

## 3. 后端实现

### 3.1 WebSocket 服务器

#### 3.1.1 基本设置

- 实现 WebSocket 服务器，监听 `/ws/remote` 路径
- 支持标准 WebSocket 协议
- 支持通过请求头进行认证

#### 3.1.2 认证流程

1. 接收 WebSocket 连接请求
2. 从请求头中获取 `Authorization` 字段
3. 验证 token 的有效性
4. 如果 token 无效，拒绝连接（返回 401 状态码）
5. 如果 token 有效，建立连接并关联用户信息

#### 3.1.3 连接管理

- 维护用户 ID 与 WebSocket 连接的映射关系
- 处理连接断开事件，从映射中移除用户
- 定期检查连接状态，清理无效连接

### 3.2 推送通知逻辑

#### 3.2.1 通知类型

| 类型 | 描述 | 数据结构 |
|------|------|----------|
| `incoming_call` | 来电通知 | `{caller_id, caller_name, caller_avatar, call_id}` |
| `message` | 消息通知 | `{sender_id, sender_name, content, conversation_id}` |
| `system` | 系统通知 | `{title, content, action}` |

#### 3.2.2 发送通知

- 实现向特定用户发送通知的功能
- 实现向所有用户广播通知的功能
- 确保通知的可靠送达

### 3.3 API 接口

#### 3.3.1 发送通知 API

- **路径**：`/api/notification/send`
- **方法**：POST
- **功能**：向指定用户发送推送通知
- **请求参数**：
  ```json
  {
    "user_id": "123",
    "type": "incoming_call",
    "data": {
      "caller_id": "456",
      "caller_name": "张三",
      "caller_avatar": "https://example.com/avatar.jpg",
      "call_id": "789"
    }
  }
  ```
- **响应**：
  ```json
  {
    "code": 200,
    "message": "发送成功",
    "success": true
  }
  ```

#### 3.3.2 批量发送通知 API

- **路径**：`/api/notification/send-batch`
- **方法**：POST
- **功能**：向多个用户发送相同的通知
- **请求参数**：
  ```json
  {
    "user_ids": ["123", "456"],
    "type": "system",
    "data": {
      "title": "系统通知",
      "content": "系统将于明天进行维护",
      "action": "none"
    }
  }
  ```
- **响应**：
  ```json
  {
    "code": 200,
    "message": "发送成功",
    "success": true
  }
  ```

#### 3.3.3 广播通知 API

- **路径**：`/api/notification/broadcast`
- **方法**：POST
- **功能**：向所有在线用户广播通知
- **请求参数**：
  ```json
  {
    "type": "system",
    "data": {
      "title": "系统通知",
      "content": "新功能上线啦！",
      "action": "none"
    }
  }
  ```
- **响应**：
  ```json
  {
    "code": 200,
    "message": "广播成功",
    "success": true
  }
  ```

## 4. 数据结构

### 4.1 WebSocket 消息格式

#### 4.1.1 通知消息

```json
{
  "type": "notification",
  "data": {
    "type": "incoming_call",
    "caller_id": "456",
    "caller_name": "张三",
    "caller_avatar": "https://example.com/avatar.jpg",
    "call_id": "789"
  }
}
```

#### 4.1.2 响应消息

```json
{
  "type": "result",
  "request_id": "req_123",
  "payload": {
    "success": true,
    "data": {}
  }
}
```

## 5. 错误处理

### 5.1 WebSocket 连接错误

- **401 Unauthorized**：token 无效或过期
- **403 Forbidden**：用户无权限建立连接
- **500 Internal Server Error**：服务器内部错误

### 5.2 推送通知错误

- **404 Not Found**：目标用户不存在或不在线
- **400 Bad Request**：请求参数错误
- **500 Internal Server Error**：服务器内部错误

## 6. 测试方法

### 6.1 连接测试

1. 使用浏览器开发者工具建立 WebSocket 连接
2. 检查连接是否成功建立
3. 检查认证是否正确处理

### 6.2 通知测试

1. 调用 `/api/notification/send` API 发送通知
2. 检查前端是否收到通知
3. 检查前端是否正确处理通知（如显示来电界面）

### 6.3 压力测试

1. 模拟多个用户同时连接
2. 发送大量通知
3. 检查系统稳定性和响应速度

## 7. 部署建议

- 使用负载均衡器处理大量 WebSocket 连接
- 实现连接池管理，优化资源使用
- 配置适当的超时和心跳机制，确保连接稳定
- 监控 WebSocket 连接状态，及时发现和解决问题

## 8. 安全考虑

- 确保 token 验证的安全性
- 防止 WebSocket 连接被恶意攻击
- 限制单个用户的连接数
- 对消息内容进行验证，防止注入攻击

## 9. 示例代码

### 9.1 Node.js 示例

```javascript
const WebSocket = require('ws');
const http = require('http');
const express = require('express');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws/remote' });

// 存储用户连接
const userConnections = new Map();

// 验证 token 函数
function validateToken(token) {
  // 这里实现 token 验证逻辑
  // 返回用户信息或 null
  return { id: '123', name: '用户' };
}

wss.on('connection', (ws, req) => {
  // 验证 token
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    ws.close(401, 'Unauthorized');
    return;
  }

  const user = validateToken(token);
  if (!user) {
    ws.close(401, 'Invalid token');
    return;
  }

  // 存储用户连接
  userConnections.set(user.id, ws);
  console.log(`User ${user.id} connected`);

  // 处理消息
  ws.on('message', (message) => {
    console.log(`Received message: ${message}`);
    // 处理前端发送的消息
  });

  // 处理连接关闭
  ws.on('close', () => {
    userConnections.delete(user.id);
    console.log(`User ${user.id} disconnected`);
  });

  // 处理错误
  ws.on('error', (error) => {
    console.error(`WebSocket error: ${error}`);
  });
});

// 发送通知的函数
function sendNotification(userId, notification) {
  const ws = userConnections.get(userId);
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({
      type: 'notification',
      data: notification
    }));
    return true;
  }
  return false;
}

// API 路由
app.post('/api/notification/send', (req, res) => {
  const { user_id, type, data } = req.body;
  const success = sendNotification(user_id, { type, ...data });
  if (success) {
    res.json({ code: 200, message: '发送成功', success: true });
  } else {
    res.json({ code: 404, message: '用户不在线', success: false });
  }
});

server.listen(8080, () => {
  console.log('Server listening on port 8080');
});
```

### 9.2 Go 示例

```go
package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // 允许所有来源，生产环境应该限制
	},
}

// 用户连接映射
var userConnections = make(map[string]*websocket.Conn)

// 通知消息结构
type NotificationMessage struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

// 发送通知
func sendNotification(userId string, notification interface{}) bool {
	conn, ok := userConnections[userId]
	if !ok {
		return false
	}

	message := NotificationMessage{
		Type: "notification",
		Data: notification,
	}

	data, err := json.Marshal(message)
	if err != nil {
		log.Println("Error marshaling notification:", err)
		return false
	}

	err = conn.WriteMessage(websocket.TextMessage, data)
	if err != nil {
		log.Println("Error sending notification:", err)
		delete(userConnections, userId)
		return false
	}

	return true
}

// WebSocket 处理函数
func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	// 验证 token
	token := r.Header.Get("Authorization")
	if token == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// 这里实现 token 验证逻辑
	// 假设验证成功，获取用户 ID
	userId := "123" // 实际应该从 token 中解析

	// 升级 HTTP 连接为 WebSocket
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Error upgrading connection:", err)
		return
	}

	// 存储用户连接
	userConnections[userId] = conn
	log.Printf("User %s connected", userId)

	// 处理消息
	go func() {
		defer func() {
			delete(userConnections, userId)
			conn.Close()
			log.Printf("User %s disconnected", userId)
		}()

		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					log.Printf("WebSocket error: %v", err)
				}
				break
			}
			log.Printf("Received message: %s", message)
			// 处理前端发送的消息
		}
	}()
}

// 发送通知 API
func sendNotificationHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID string      `json:"user_id"`
		Type   string      `json:"type"`
		Data   interface{} `json:"data"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	success := sendNotification(req.UserID, map[string]interface{}{
		"type": req.Type,
		"data": req.Data,
	})

	if success {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"code":    200,
			"message": "发送成功",
			"success": true,
		})
	} else {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"code":    404,
			"message": "用户不在线",
			"success": false,
		})
	}
}

func main() {
	http.HandleFunc("/ws/remote", handleWebSocket)
	http.HandleFunc("/api/notification/send", sendNotificationHandler)

	log.Println("Server listening on port 8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal("Error starting server:", err)
	}
}
```

## 10. 总结

本文档详细说明了如何实现基于 WebSocket 的推送通知功能，包括前端实现、后端实现、API 接口、数据结构、测试方法等。后端开发人员可以根据本文档实现相应的功能，与前端进行对接，实现完整的推送通知系统。

通过 WebSocket 实现推送通知，不仅可以避免 Firebase 初始化失败的问题，还可以提供更实时、更可靠的通知服务，提升用户体验。