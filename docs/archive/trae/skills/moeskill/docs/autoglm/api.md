# AutoGLM API 接口

## 概述

AutoGLM系统通过一系列API接口实现前端与Android原生服务之间的通信，以及与AI模型的交互。本指南将详细介绍AutoGLM的API接口设计和使用方法。

## 接口类型

AutoGLM的API接口主要分为以下几类：

1. **方法通道**：前端调用Android原生服务的方法
2. **事件通道**：Android原生服务向前端发送事件
3. **HTTP API**：与后端服务和AI模型的通信

## 方法通道

### 设备操作接口

#### 执行点击操作

**方法名**：`performClick`

**参数**：
- `x`：点击坐标X
- `y`：点击坐标Y

**返回值**：
- `success`：操作是否成功
- `error`：错误信息（如果有）

**示例**：
```dart
// Flutter端调用
var result = await platform.invokeMethod('performClick', {
  'x': 500,
  'y': 800,
});

// Kotlin端实现
override fun onMethodCall(call: MethodCall, result: Result) {
  when (call.method) {
    "performClick" -> {
      val x = call.argument<Int>("x") ?: 0
      val y = call.argument<Int>("y") ?: 0
      val success = deviceController.performClick(x, y)
      result.success(mapOf("success" to success))
    }
  }
}
```

#### 执行滑动操作

**方法名**：`performSwipe`

**参数**：
- `startX`：起始坐标X
- `startY`：起始坐标Y
- `endX`：结束坐标X
- `endY`：结束坐标Y
- `duration`：滑动持续时间（毫秒）

**返回值**：
- `success`：操作是否成功
- `error`：错误信息（如果有）

#### 输入文本

**方法名**：`inputText`

**参数**：
- `text`：要输入的文本

**返回值**：
- `success`：操作是否成功
- `error`：错误信息（如果有）

#### 打开应用

**方法名**：`openApp`

**参数**：
- `packageName`：应用包名

**返回值**：
- `success`：操作是否成功
- `error`：错误信息（如果有）

### 屏幕分析接口

#### 分析屏幕

**方法名**：`analyzeScreen`

**参数**：无

**返回值**：
- `elements`：屏幕元素列表
  - `text`：元素文本
  - `bounds`：元素边界
  - `className`：元素类名
- `error`：错误信息（如果有）

#### 查找元素

**方法名**：`findElement`

**参数**：
- `text`：要查找的文本
- `className`：元素类名（可选）

**返回值**：
- `element`：找到的元素
  - `text`：元素文本
  - `bounds`：元素边界
  - `className`：元素类名
- `found`：是否找到
- `error`：错误信息（如果有）

### 系统接口

#### 获取系统信息

**方法名**：`getSystemInfo`

**参数**：无

**返回值**：
- `osVersion`：操作系统版本
- `deviceModel`：设备型号
- `screenWidth`：屏幕宽度
- `screenHeight`：屏幕高度
- `error`：错误信息（如果有）

#### 获取应用列表

**方法名**：`getInstalledApps`

**参数**：无

**返回值**：
- `apps`：应用列表
  - `packageName`：应用包名
  - `appName`：应用名称
  - `icon`：应用图标（Base64编码）
- `error`：错误信息（如果有）

## 事件通道

### 系统事件

#### 屏幕变化事件

**通道名**：`screenChanged`

**事件数据**：
- `elements`：屏幕元素列表
- `timestamp`：事件时间戳

**示例**：
```dart
// Flutter端监听
const eventChannel = EventChannel('autoglm/screen');
eventChannel.receiveBroadcastStream().listen(
  (event) {
    print('Screen changed: $event');
  },
  onError: (error) {
    print('Error: $error');
  },
);

// Kotlin端发送
private val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "autoglm/screen")
eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    this.events = events
  }
  
  fun sendScreenChangeEvent(elements: List<ScreenElement>) {
    events?.success(mapOf(
      "elements" to elements.map { it.toMap() },
      "timestamp" to System.currentTimeMillis()
    ))
  }
})
```

#### 操作结果事件

**通道名**：`operationResult`

**事件数据**：
- `operation`：操作类型
- `success`：操作是否成功
- `message`：操作结果消息
- `timestamp`：事件时间戳

### AI事件

#### 意图识别事件

**通道名**：`intentRecognized`

**事件数据**：
- `intent`：识别的意图
- `entities`：提取的实体
- `confidence`：置信度
- `timestamp`：事件时间戳

#### 任务完成事件

**通道名**：`taskCompleted`

**事件数据**：
- `taskId`：任务ID
- `result`：任务结果
- `success`：任务是否成功
- `timestamp`：事件时间戳

## HTTP API

### AI模型接口

#### 分析意图

**端点**：`POST /api/ai/analyze`

**请求体**：
```json
{
  "text": "打开微信并发送消息给张三",
  "context": {}
}
```

**响应**：
```json
{
  "intent": "send_message",
  "entities": {
    "app": "微信",
    "recipient": "张三"
  },
  "confidence": 0.95
}
```

#### 生成任务计划

**端点**：`POST /api/ai/plan`

**请求体**：
```json
{
  "intent": "send_message",
  "entities": {
    "app": "微信",
    "recipient": "张三"
  }
}
```

**响应**：
```json
{
  "tasks": [
    {
      "type": "open_app",
      "params": {
        "app": "微信"
      }
    },
    {
      "type": "find_contact",
      "params": {
        "name": "张三"
      }
    },
    {
      "type": "send_message",
      "params": {
        "contact": "张三"
      }
    }
  ]
}
```

### 记忆管理接口

#### 存储记忆

**端点**：`POST /api/memory/store`

**请求体**：
```json
{
  "userId": "123",
  "memory": {
    "content": "用户喜欢在晚上8点听音乐",
    "type": "preference",
    "importance": 0.8
  }
}
```

**响应**：
```json
{
  "success": true,
  "memoryId": "456"
}
```

#### 检索记忆

**端点**：`GET /api/memory/retrieve`

**查询参数**：
- `userId`：用户ID
- `query`：查询关键词
- `limit`：返回数量限制

**响应**：
```json
{
  "memories": [
    {
      "id": "456",
      "content": "用户喜欢在晚上8点听音乐",
      "type": "preference",
      "timestamp": "2023-10-01T20:00:00Z",
      "importance": 0.8
    }
  ]
}
```

### 设备管理接口

#### 获取设备状态

**端点**：`GET /api/device/status`

**响应**：
```json
{
  "battery": 85,
  "network": "wifi",
  "screen": "on",
  "apps": [
    "com.tencent.mm",
    "com.google.android.youtube"
  ]
}
```

#### 执行设备操作

**端点**：`POST /api/device/operate`

**请求体**：
```json
{
  "operation": "click",
  "params": {
    "x": 500,
    "y": 800
  }
}
```

**响应**：
```json
{
  "success": true,
  "message": "Operation executed successfully"
}
```

## API设计原则

### 一致性

- **命名规范**：使用清晰、一致的命名规范
- **参数格式**：统一参数格式和数据类型
- **响应格式**：统一响应格式，包含成功状态和错误信息

### 可靠性

- **错误处理**：完善的错误处理机制
- **重试机制**：对于网络请求实现重试机制
- **超时处理**：设置合理的超时时间

### 安全性

- **认证授权**：实现API认证和授权
- **数据加密**：加密传输敏感数据
- **输入验证**：验证输入参数的合法性

### 性能

- **响应速度**：优化API响应速度
- **资源利用**：合理利用系统资源
- **缓存策略**：实现适当的缓存策略

## 最佳实践

### 前端调用

1. **错误处理**：妥善处理API调用错误
2. **异步操作**：使用异步方式调用API
3. **状态管理**：合理管理API调用状态
4. **参数验证**：在调用前验证参数

### 后端实现

1. **模块化**：将API实现模块化
2. **日志记录**：记录API调用日志
3. **监控**：监控API性能和错误
4. **版本控制**：实现API版本控制

### 测试

1. **单元测试**：测试API的各个组件
2. **集成测试**：测试API与其他系统的集成
3. **性能测试**：测试API的性能
4. **安全测试**：测试API的安全性

## 总结

AutoGLM的API接口设计提供了前端与Android原生服务、AI模型之间的通信桥梁。通过合理的API设计和实现，可以确保系统各组件之间的高效通信，为用户提供流畅的智能助手体验。

在实际开发中，应根据具体需求和技术栈，选择合适的API实现方式，并不断优化API性能和可靠性，以满足用户的需求。