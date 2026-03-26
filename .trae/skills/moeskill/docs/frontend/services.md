# 服务模块库

## 概述

本项目包含一系列可复用的服务模块，用于处理应用中的各种功能，如网络请求、推送通知、WebSocket 连接等。这些服务模块遵循单一职责原则，提供清晰的 API 接口，方便在应用的不同部分复用。

## 核心服务

### 1. API 服务

#### ApiService

处理与后端 API 的通信，包括请求封装、认证、错误处理等。

```dart
// 初始化
ApiService.init('https://api.example.com');

// 设置认证 token
ApiService.setToken('your-token-here');

// 发送 GET 请求
final response = await ApiService.get('/api/users');

// 发送 POST 请求
final response = await ApiService.post('/api/users', {
  'name': 'John Doe',
  'email': 'john@example.com',
});
```

#### 特性
- 统一的 API 基础 URL 管理
- 自动添加认证 token
- 统一的错误处理
- 支持 GET、POST、PUT、DELETE 等 HTTP 方法
- 支持自定义请求头和参数

### 2. 聊天推送服务

#### ChatPushService

处理实时聊天消息的 WebSocket 连接和消息推送。

```dart
// 初始化
ChatPushService.initialize(AuthService.navigatorKey);

// 启动服务
ChatPushService.start();

// 停止服务
ChatPushService.stop();

// 监听消息
ChatPushService.incomingMessages.listen((message) {
  print('收到消息: ${message['content']}');
});

// 标记发送者已读
ChatPushService.markSenderRead('sender-id');

// 获取未读消息
final pendingMessages = ChatPushService.takePendingMessages('sender-id');
```

#### 特性
- 实时 WebSocket 连接
- 自动重连机制
- 消息暂存队列
- 未读消息计数
- 消息通知弹窗
- 支持心跳检测

### 3. 推送通知服务

#### PushNotificationService

处理应用的推送通知，包括消息接收和处理。

```dart
// 初始化
await PushNotificationService.initialize(AuthService.navigatorKey);

// 获取推送令牌
final token = await PushNotificationService.getToken();

// 模拟来电通知
PushNotificationService.simulateIncomingCall(
  'caller-id',
  '张三',
  'https://example.com/avatar.jpg',
  'call-id',
);
```

#### 特性
- WebSocket 模式推送
- 来电通知处理
- 支持令牌获取
- 模拟通知功能

### 4. 远程控制服务

#### RemoteControlService

处理远程控制功能，如设备控制、远程操作等。

```dart
// 初始化
await RemoteControlService.init();

// 发送远程命令
await RemoteControlService.sendCommand('device-id', 'command', {'param': 'value'});
```

#### 特性
- WebSocket 连接管理
- 命令发送和接收
- 设备状态管理
- 错误处理和重连

### 5. 在线状态服务

#### PresenceService

管理用户的在线状态，包括状态同步和通知。

```dart
// 启动服务
PresenceService.start();

// 停止服务
PresenceService.stop();

// 监听状态变化
PresenceService.presenceStream.listen((status) {
  print('状态变化: $status');
});
```

#### 特性
- WebSocket 连接管理
- 在线状态同步
- 状态变化通知
- 自动重连机制

### 6. 通知服务

#### NotificationService

处理应用内通知，包括获取通知列表、标记已读等。

```dart
// 初始化本地通知
await NotificationService.initLocalNotifications();

// 获取通知列表
final notifications = await NotificationService.getNotifications(page: 1);

// 标记通知已读
await NotificationService.markAsRead('notification-id');

// 清除所有通知
await NotificationService.clearAllNotifications();
```

#### 特性
- 本地通知支持
- 通知列表获取
- 通知状态管理
- 错误处理和重试

### 7. 认证服务

#### AuthService

处理用户认证，包括登录、注册、令牌管理等。

```dart
// 初始化
await AuthService.init();

// 登录
final result = await AuthService.login('username', 'password');

// 注册
final result = await AuthService.register('username', 'email', 'password');

// 登出
await AuthService.logout();

// 检查登录状态
final isLoggedIn = AuthService.isLoggedIn;
```

#### 特性
- 令牌管理
- 登录状态持久化
- 导航键管理
- 错误处理和重试

### 8. 无障碍服务

#### AccessibilityOverlayService

处理应用的无障碍功能，如悬浮窗等。

```dart
// 初始化
AccessibilityOverlayService.init();

// 显示悬浮窗
AccessibilityOverlayService.showOverlay();

// 隐藏悬浮窗
AccessibilityOverlayService.hideOverlay();
```

#### 特性
- 悬浮窗管理
- 无障碍功能支持
- 权限管理

### 9. 更新服务

#### UpdateService

处理应用更新，包括检查更新、下载更新等。

```dart
// 检查更新
await UpdateService.checkForUpdates(context);

// 手动检查更新
UpdateService.checkForUpdates(context, forceCheck: true);
```

#### 特性
- 版本检查
- 更新下载
- 更新安装
- 进度显示

## 使用指南

### 导入服务

```dart
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/services/chat_push_service.dart';
import 'package:moe_social/services/push_notification_service.dart';
```

### 服务初始化

在应用启动时初始化必要的服务：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化认证服务
  await AuthService.init();
  
  // 初始化 API 服务
  ApiService.init('https://api.example.com');
  
  // 初始化推送通知服务
  await PushNotificationService.initialize(AuthService.navigatorKey);
  
  // 初始化聊天推送服务
  ChatPushService.initialize(AuthService.navigatorKey);
  
  // 启动服务
  if (AuthService.isLoggedIn) {
    ChatPushService.start();
    PresenceService.start();
  }
  
  runApp(MyApp());
}
```

### 服务使用最佳实践

1. **单一职责**：每个服务只负责一个功能领域
2. **依赖注入**：通过构造函数或全局访问点提供服务
3. **错误处理**：每个服务都应该有完善的错误处理机制
4. **状态管理**：使用 ValueNotifier、Stream 等管理服务状态
5. **资源管理**：及时释放资源，如 WebSocket 连接、定时器等
6. **可测试性**：设计服务时考虑可测试性，便于单元测试

### 服务扩展

如果现有服务不能满足需求，可以创建自定义服务：

```dart
class MyCustomService {
  static final MyCustomService _instance = MyCustomService._();
  factory MyCustomService() => _instance;
  
  MyCustomService._();
  
  Future<void> initialize() async {
    // 初始化逻辑
  }
  
  Future<dynamic> doSomething() async {
    // 业务逻辑
  }
}
```

## 常见问题

1. **WebSocket 连接失败**
   - 检查网络连接
   - 检查后端 WebSocket 服务是否正常
   - 检查认证 token 是否有效

2. **推送通知不显示**
   - 检查 PushNotificationService 是否正确初始化
   - 检查 WebSocket 连接是否正常
   - 检查消息格式是否正确

3. **服务初始化失败**
   - 检查依赖是否正确导入
   - 检查初始化顺序是否正确
   - 检查权限是否正确配置

4. **服务资源泄漏**
   - 确保在适当的时候调用 stop() 方法
   - 确保定时器、StreamSubscription 等资源被正确释放
   - 使用 try-finally 确保资源释放

## 总结

本项目的服务模块库提供了一套完整的功能服务，帮助开发者快速构建应用的核心功能。通过使用这些服务，可以确保应用的功能一致性和代码的可维护性。

在开发过程中，应优先使用现有服务，并遵循服务的使用规范，以保持应用的整体架构清晰和一致。