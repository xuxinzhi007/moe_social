# 错误处理

> **本文档描述项目实际的错误处理机制。**

---

## 项目错误通知的两个通道

项目中存在**两套**反馈方式，混用会让用户收不到提示：

| 通道 | 实现 | 有效范围 |
|------|------|----------|
| **MoeToast**（推荐） | `MoeToast.success/error(context, msg)` | 需要页面级 context（在 Navigator Overlay 内部） |
| **ScaffoldMessenger SnackBar** | `ErrorHandler.show(context, msg)` | 部分旧页面仍在使用，如 `home_page.dart` |

**新功能统一使用 MoeToast**，不要混用 SnackBar。

---

## ApiException —— 项目统一错误类型

`lib/services/api_service.dart` 中定义：

```dart
class ApiException implements Exception {
  final String message;  // 用户可读的错误信息
  final int? code;       // HTTP 状态码或业务错误码
}
```

`ApiService` 在以下情况抛出 `ApiException`：
- HTTP 4xx / 5xx
- 后端返回 `success: false`（Go-zero 格式）
- 401 token 过期且刷新失败（会先尝试 `_refreshToken` 重试一次，失败后才抛出）
- 特殊情况：cpolar 隧道 404/502、HTML 响应等

**`executeOperation` 自动捕获 `ApiException`**，所以页面里通常不需要自己 try-catch：

```dart
// ✅ 交给 executeOperation 处理
await loadingProvider.executeOperation(
  operation: () => ApiService.someCall(),
  onError: (_) {}, // errorMessage 已自动设置，此处通常留空
);

// ⚠️ 直接调用 API 时需要自己处理
try {
  final result = await ApiService.someCall();
} on ApiException catch (e) {
  MoeToast.error(context, e.message);
} catch (e) {
  MoeToast.error(context, '操作失败：$e');
}
```

---

## MoeToast 正确使用方式

详见 `docs/frontend/ui-components.md`，核心规则：

```dart
// ✅ 用页面的 context（在 Overlay 内部）
MoeToast.success(context, '操作成功');
MoeToast.error(context, '出错了');

// ✅ 导航前先 toast，toast 已插入 Overlay，跳转后依然可见
MoeToast.success(context, '登录成功！');
Navigator.pushReplacementNamed(context, '/home');

// ❌ navigatorKey.currentContext 在 Overlay 上方，无法显示
MoeToast.success(AuthService.navigatorKey.currentContext!, '...');

// ❌ loadingProvider.setSuccess() 经 AppMessageWidget 中转，
//    AppMessageWidget 的 context 也在 Overlay 上方，同样无法显示
loadingProvider.setSuccess('...');
```

---

## 401 自动登出机制

`ApiService` 在 token 失效时会：
1. 尝试调用 `_refreshToken` 刷新
2. 成功：更新 token，重试原请求
3. 失败：调用 `_onLogoutCallback`（即 `AuthService.logout()`），并抛出 `ApiException('登录已过期，请重新登录', 401)`

**开发时不要在除 `ApiService._onLogoutCallback` 之外的地方处理 401**，避免重复弹窗或重复跳转。

---

## 全局 Flutter 错误捕获

`main.dart` 中已配置以下全局错误处理：

```dart
// Flutter 框架错误（widget build/layout 异常）
FlutterError.onError = (details) { ... 打印到控制台 ... };

// 渲染错误时替换页面（不白屏）
ErrorWidget.builder = (details) { return 萌系错误卡片 Widget; };

// 平台异步错误
PlatformDispatcher.instance.onError = (error, stack) { ...; return true; };

// Zone 内未捕获的错误
runZonedGuarded(() { ... }, (error, stack) { ... });
```

遇到页面崩溃时，控制台会打印 `═══` 分隔线，查找**第一条**异常（不是重复的 `hasSize` 错误）。

---

## 点赞状态 isLiked 服务端不可信

服务端 List 接口返回的 `isLiked` **不可靠**，本地用 `LikeStateManager` + `AuthService.getLikeStatus` 做合并覆盖。新功能如果需要处理点赞状态，直接复用 `PostService` 中已有的合并逻辑，不要信任服务端返回值。
