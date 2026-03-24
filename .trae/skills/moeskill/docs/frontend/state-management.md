# 状态管理

> **本文档描述项目实际使用的状态管理方案。** 项目只使用 Provider，不使用 Riverpod / Bloc。

## 项目 Provider 全览

在 `main.dart` 的 `MultiProvider` 中注册，全局可用：

| Provider | 作用 |
|----------|------|
| `LoadingProvider` | 全局/操作级加载状态 + 统一消息（success/error） |
| `ThemeProvider` | 主题切换（亮色/暗色），持久化到 prefs |
| `NotificationProvider` | 未读消息数、push 通知、在线状态轮询 |
| `DeviceInfoProvider` | 设备信息同步 |
| `CheckInProvider` | 签到状态（自带独立 loading/error 字段） |
| `UserLevelProvider` | 用户等级和经验值 |
| `GameProvider` | 游戏状态 |

---

## LoadingProvider —— 核心用法

### executeOperation（推荐模式）

所有涉及 API 调用的操作优先使用 `executeOperation`，统一处理加载状态：

```dart
final loadingProvider = context.read<LoadingProvider>();

await loadingProvider.executeOperation<MyResult>(
  operation: () => ApiService.someCall(),  // 必须返回 Future<T>
  key: LoadingKeys.someKey,               // 使用操作级加载（不传则用全局 isLoading）
  onSuccess: (result) {
    // 成功后的操作（在 UI 线程）
    MoeToast.success(context, '操作成功');
    Navigator.pop(context);
  },
  onError: (_) {},  // 错误已被 executeOperation 自动 setError，一般不需要额外处理
);
```

**关键行为：**
- 调用前自动 `clearMessages()`（会清除上一次的 success/error）
- 捕获 `ApiException` 并自动 `setError(e.message)`
- 捕获通用 `Exception` 并自动 `setError('操作失败: $e')`
- `finally` 里自动清除 loading 状态

### 操作级 key vs 全局 loading

```dart
// 推荐：操作级 key，只禁用该按钮，不遮罩整个页面
key: LoadingKeys.login,     // 对应 LoadingButton(operationKey: LoadingKeys.login)

// 慎用：不传 key 时用全局 isLoading，会触发整页遮罩（AppMessageWidget 里的 MoeLoading）
// 适合无法局部显示进度的场景（如全局初始化）
```

### LoadingKeys 完整列表

```dart
// lib/providers/loading_provider.dart
class LoadingKeys {
  static const String login = 'login';
  static const String register = 'register';
  static const String createPost = 'createPost';
  // ... 查看源码获取完整列表
}
```

### LoadingButton —— 配套按钮组件

`LoadingButton` 和 `executeOperation` 的 `key` 必须一致，否则按钮不会在操作期间禁用：

```dart
LoadingButton(
  operationKey: LoadingKeys.login,  // 与 executeOperation key 相同
  onPressed: _login,
  child: const Text('登 录'),
  style: ElevatedButton.styleFrom(...),
)
```

---

## 重要陷阱：AuthResult 成功不等于登录成功

`AuthService.login` / `register` **内部吞掉了 ApiException**，始终返回 `AuthResult`（不抛出）。因此 `executeOperation` 的 `onSuccess` 一定会被调用，**必须手动检查 `result.success`**：

```dart
// ✅ 正确
onSuccess: (result) {
  if (!result.success) {
    MoeToast.error(context, result.errorMessage ?? '登录失败');
    return;
  }
  // 真正登录成功才继续
  MoeToast.success(context, '欢迎回来！');
  Navigator.pushReplacementNamed(context, '/home');
},

// ❌ 错误：认为 onSuccess 被调用就代表成功
onSuccess: (result) {
  Navigator.pushReplacementNamed(context, '/home'); // 密码错也会走到这里！
},
```

---

## NotificationProvider

**登录成功后必须调用 `init()`**，否则 push 通知、未读数、在线状态不会启动：

```dart
onSuccess: (result) {
  if (!result.success) { ... return; }
  try { context.read<NotificationProvider>().init(); } catch (_) {}
  // 再导航
}
```

`init()` 内部会检查 `AuthService.isLoggedIn`，未登录时直接返回，所以提前调用没有副作用。

---

## CheckInProvider / UserLevelProvider

这两个 Provider **有自己独立的 loading/error 字段**，不依赖 `LoadingProvider`。使用时通过 `Consumer` 或 `context.watch` 读取它们自己的状态。

---

## context.read vs context.watch

| 用法 | 场景 |
|------|------|
| `context.read<T>()` | 在回调/事件处理器里一次性读取，**不监听变化**（推荐用于按钮回调） |
| `context.watch<T>()` | 在 `build` 方法里，Provider 变化时自动重建 |
| `Consumer<T>` | 只重建 Consumer 内部的子树，比 `context.watch` 粒度更细 |
