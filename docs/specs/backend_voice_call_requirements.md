# 语音通话功能后端需求文档

## 1. 概述

本文档描述了Moe Social应用中语音通话功能的后端需求，包括API接口设计、数据库设计、推送通知服务等内容。

## 2. 技术栈

- **后端框架**：Go + go-zero
- **数据库**：MySQL/PostgreSQL
- **推送服务**：Firebase Cloud Messaging (FCM)
- **实时通信**：Agora RTC

## 3. 数据库设计

### 3.1 呼叫状态表

```sql
CREATE TABLE `calls` (
  `id` VARCHAR(36) PRIMARY KEY,
  `caller_id` VARCHAR(36) NOT NULL,
  `receiver_id` VARCHAR(36) NOT NULL,
  `status` ENUM('initiated', 'ringing', 'answered', 'rejected', 'cancelled', 'ended') NOT NULL,
  `channel_name` VARCHAR(100) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`caller_id`) REFERENCES `users`(`id`),
  FOREIGN KEY (`receiver_id`) REFERENCES `users`(`id`)
);
```

### 3.2 用户设备表

```sql
CREATE TABLE `user_devices` (
  `id` VARCHAR(36) PRIMARY KEY,
  `user_id` VARCHAR(36) NOT NULL,
  `device_token` VARCHAR(255) NOT NULL,
  `device_type` ENUM('android', 'ios', 'web') NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`)
);
```

## 4. API接口设计

### 4.1 语音通话Token获取

**接口**：`GET /api/voice/token`

**参数**：
- `channel_name`：通话频道名称
- `role`：用户角色（1: 主播，2: 观众）

**响应**：
```json
{
  "code": 200,
  "message": "操作成功",
  "success": true,
  "data": {
    "token": "<Agora RTC Token>",
    "app_id": "<Agora App ID>"
  }
}
```

### 4.2 发起语音呼叫

**接口**：`POST /api/voice/call`

**参数**：
- `receiver_id`：接收方用户ID

**响应**：
```json
{
  "code": 200,
  "message": "操作成功",
  "success": true,
  "data": {
    "call_id": "<呼叫ID>",
    "channel_name": "<通话频道名称>"
  }
}
```

### 4.3 接听语音呼叫

**接口**：`POST /api/voice/answer`

**参数**：
- `call_id`：呼叫ID

**响应**：
```json
{
  "code": 200,
  "message": "操作成功",
  "success": true,
  "data": {
    "channel_name": "<通话频道名称>"
  }
}
```

### 4.4 拒绝语音呼叫

**接口**：`POST /api/voice/reject`

**参数**：
- `call_id`：呼叫ID

**响应**：
```json
{
  "code": 200,
  "message": "操作成功",
  "success": true,
  "data": {}
}
```

### 4.5 取消语音呼叫

**接口**：`POST /api/voice/cancel`

**响应**：
```json
{
  "code": 200,
  "message": "操作成功",
  "success": true,
  "data": {}
}
```

## 5. 推送通知服务

### 5.1 服务设计

- **服务名称**：`push_service`
- **功能**：处理推送通知的发送，包括语音通话呼叫通知

### 5.2 实现逻辑

1. 当用户发起语音呼叫时，后端生成唯一的呼叫ID和频道名称
2. 保存呼叫状态到数据库
3. 调用推送服务发送呼叫通知给接收方
4. 接收方收到通知后，显示来电界面
5. 接收方接听或拒绝呼叫时，更新呼叫状态
6. 通知发起方呼叫状态变化

### 5.3 通知格式

**呼叫通知**：
```json
{
  "data": {
    "type": "incoming_call",
    "caller_id": "<呼叫方ID>",
    "caller_name": "<呼叫方名称>",
    "caller_avatar": "<呼叫方头像>",
    "call_id": "<呼叫ID>",
    "channel_name": "<通话频道名称>"
  },
  "notification": {
    "title": "来电",
    "body": "<呼叫方名称>正在呼叫您",
    "sound": "default"
  }
}
```

## 6. 业务逻辑

### 6.1 呼叫发起流程

1. 呼叫方发起语音呼叫请求
2. 后端生成呼叫ID和频道名称
3. 保存呼叫状态为`initiated`
4. 调用Agora API生成RTC Token
5. 发送推送通知给接收方
6. 更新呼叫状态为`ringing`
7. 返回呼叫ID和频道名称给呼叫方

### 6.2 呼叫接收流程

1. 接收方收到推送通知
2. 接收方点击通知，显示来电界面
3. 接收方选择接听或拒绝
4. 如果接听：
   - 调用接听API
   - 更新呼叫状态为`answered`
   - 返回频道名称给接收方
   - 通知呼叫方呼叫已被接听
5. 如果拒绝：
   - 调用拒绝API
   - 更新呼叫状态为`rejected`
   - 通知呼叫方呼叫已被拒绝

### 6.3 呼叫取消流程

1. 呼叫方点击取消呼叫
2. 调用取消API
3. 更新呼叫状态为`cancelled`
4. 通知接收方呼叫已被取消

## 7. 错误处理

| 错误码 | 错误消息 | 描述 |
|--------|---------|------|
| 400 | 参数错误 | 请求参数不合法 |
| 401 | 未授权 | 用户未登录 |
| 404 | 用户不存在 | 接收方用户不存在 |
| 409 | 呼叫已存在 | 已有未完成的呼叫 |
| 500 | 服务器错误 | 服务器内部错误 |
| 503 | 推送服务不可用 | 推送通知发送失败 |

## 8. 性能优化

1. **缓存**：缓存Agora RTC Token，减少API调用
2. **异步处理**：使用消息队列处理推送通知，提高响应速度
3. **数据库索引**：为`calls`表的`receiver_id`和`status`字段添加索引
4. **连接池**：使用数据库连接池，减少数据库连接开销

## 9. 安全考虑

1. **Token验证**：验证用户Token，确保只有授权用户可以发起呼叫
2. **频道名称**：使用随机生成的频道名称，防止恶意用户加入通话
3. **RTC Token**：使用临时Token，限制Token的有效期
4. **数据加密**：确保通话数据的加密传输

## 10. 部署要求

1. **环境变量**：
   - `AGORA_APP_ID`：Agora App ID
   - `AGORA_APP_CERTIFICATE`：Agora App Certificate
   - `FCM_SERVER_KEY`：Firebase Cloud Messaging Server Key
   - `DATABASE_URL`：数据库连接字符串

2. **服务依赖**：
   - Agora RTC SDK
   - Firebase Admin SDK
   - MySQL/PostgreSQL

## 11. 测试计划

1. **单元测试**：测试API接口的基本功能
2. **集成测试**：测试完整的呼叫流程
3. **压力测试**：测试系统在高并发下的性能
4. **兼容性测试**：测试在不同设备和平台上的兼容性

## 12. 总结

本需求文档详细描述了Moe Social应用中语音通话功能的后端实现要求，包括API接口设计、数据库设计、推送通知服务等内容。通过实现这些功能，用户将能够在应用中发起和接收语音通话，提高应用的社交体验。