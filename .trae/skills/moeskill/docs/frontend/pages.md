# 页面开发与导航

> **本文档描述项目实际的路由结构和导航模式。**

## 完整路由表

`main.dart` 中注册的所有命名路由：

| 路由 | 页面 | 参数 |
|------|------|------|
| `/login` | `LoginPage` | 无 |
| `/register` | `RegisterPage` | 无 |
| `/home` | `MainPage`（含底部导航栏） | 无 |
| `/profile` | `ProfilePage` | 无 |
| `/settings` | `SettingsPage` | 无 |
| `/create-post` | `CreatePostPage` | 无 |
| `/comments` | `CommentsPage` | `String` postId |
| `/edit-profile` | `EditProfilePage` | `User` user |
| `/vip-center` | `VipCenterPage` | 无 |
| `/vip-purchase` | `VipPurchasePage` | 无 |
| `/vip-orders` | `VipOrdersPage` | 无 |
| `/vip-history` | `VipHistoryPage` | 无 |
| `/forgot-password` | `ForgotPasswordPage` | 无 |
| `/verify-code` | `VerifyCodePage` | `String` email |
| `/reset-password` | `ResetPasswordPage` | `Map<String,dynamic>` {email, code} |
| `/notifications` | `NotificationCenterPage` | 无 |
| `/wallet` | `WalletPage` | 无 |
| `/recharge` | `RechargePage` | 无 |
| `/gacha` | `GachaPage` | 无 |
| `/user-profile` | `UserProfilePage` | `Map<String,dynamic>` {userId, userName?, userAvatar?, heroTag?} |
| `/cloud-gallery` | `CloudGalleryPage` | 无 |
| `/topic-posts` | `TopicPostsPage` | `TopicTag` tag |
| `/friends` | `FriendsPage` | 无 |
| `/direct-chat` | `DirectChatPage` | `Map<String,dynamic>` {userId, username, avatar} |

### 带参数的路由写法

```dart
// 传递单个对象
Navigator.pushNamed(context, '/comments', arguments: postId);

// 传递 Map（多个参数）
Navigator.pushNamed(context, '/user-profile', arguments: {
  'userId': userId,
  'userName': name,
  'userAvatar': avatar,
  'heroTag': tag,
});
```

---

## 主页结构（MainPage）

`/home` 对应 `MainPage`，内部用 `IndexedStack` + `MoeBottomBar` 管理 5 个 Tab：

| Index | Tab | 页面 |
|-------|-----|------|
| 0 | 首页 | `HomePage` |
| 1 | 好友 | `FriendsPage` |
| 2 | AI | `AgentListPage` |
| 3 | 娱乐 | `GameLobbyPage` |
| 4 | 我的 | `ProfilePage` |

Tab 页面使用**懒加载**（首次切换时才创建），已创建的页面不会销毁。

---

## 导航模式

### 登录成功 → 首页（清空栈）

```dart
MoeToast.success(context, '欢迎回来！(｡♥♥｡)');  // 先 toast
Navigator.pushReplacementNamed(context, '/home'); // 再跳转（无法返回登录页）
```

### 注册成功 → 返回登录页

```dart
MoeToast.success(context, '欢迎加入 Moe Social！(≧∇≦)/');
Navigator.pop(context);
```

### 退出登录 → 清空所有栈

```dart
// 在 AuthService.logout() 中（不在页面里直接调用）
AuthService.logout(); // 内部使用 navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', ...)
```

### 无 context 的导航（Static / Service 层）

```dart
AuthService.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
```

---

## 重要陷阱

### 1. navigatorKey.currentContext 不能用于 MoeToast

`AuthService.navigatorKey.currentContext` 是 Navigator 自身的 context，处于 Overlay **上方**，`Overlay.maybeOf(context)` 返回 null，toast 无效。详见 `docs/frontend/ui-components.md` 中的 MoeToast 规范。

### 2. pushReplacementNamed 的 Future 语义

```dart
// ❌ 误解：.then 不是"导航完成后"，而是"目标页被 pop 后"
Navigator.pushReplacementNamed(context, '/home').then((_) {
  // 永远不会在正常流程执行，因为 /home 不会被 pop
});
```

### 3. Map 参数路由防御性写法

对于 Web 端（刷新后参数丢失），必须做 null/类型检查：

```dart
'/user-profile': (context) {
  final args = ModalRoute.of(context)?.settings.arguments;
  if (args is! Map<String, dynamic>) {
    return const Scaffold(body: Center(child: Text('页面参数丢失，请返回首页重新进入')));
  }
  return UserProfilePage(...);
},
```

### 4. 初始路由取决于登录状态

```dart
initialRoute: AuthService.isLoggedIn ? '/home' : '/login',
```

`AuthService.init()` 在 `runApp` 之前调用，所以 `isLoggedIn` 此时已确定。

---

## 页面文件位置约定

- **大部分页面** 直接放在 `lib/` 根目录（`login_page.dart`, `profile_page.dart` 等）
- **按功能分组的页面** 放在 `lib/pages/` 子目录（`pages/game/`, `pages/ai/`）
- **新增页面** 建议放到 `lib/pages/` 对应功能目录，并在 `main.dart` 路由表里注册
