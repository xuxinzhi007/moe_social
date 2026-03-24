# Flutter基础

## 概述

Flutter是一个由Google开发的开源UI工具包，用于构建跨平台应用。本项目使用Flutter来开发前端界面，支持Android、iOS、Web、Windows、macOS和Linux平台。

## 项目结构（实际目录）

```
lib/
├── main.dart                  # 应用入口、路由表、MultiProvider 注册
├── auth_service.dart          # 认证服务（login/logout/token/navigatorKey）
│
├── pages/                     # 按功能分组的页面（新页面优先放这里）
│   ├── home_page.dart         # 首页 feed
│   ├── ai/                    # AI 助手相关页面
│   └── game/                  # 游戏大厅相关页面
│
├── gallery/                   # 云相册功能
│
├── *_page.dart（根目录）       # 历史遗留页面（直接放在 lib/ 下）
│   ├── login_page.dart
│   ├── register_page.dart
│   ├── profile_page.dart
│   ├── comments_page.dart
│   ├── recharge_page.dart
│   └── ...（其余功能页）
│
├── models/                    # 数据模型（fromJson/toJson）
│   ├── user.dart
│   ├── post.dart
│   ├── notification.dart      # typedef NotificationItem = NotificationModel
│   └── topic_tag.dart
│
├── providers/                 # ChangeNotifier 状态管理
│   ├── loading_provider.dart  # 全局/操作级 loading + success/error 消息
│   ├── theme_provider.dart
│   ├── notification_provider.dart
│   ├── checkin_provider.dart
│   ├── user_level_provider.dart
│   └── game_provider.dart
│
├── services/                  # API、WebSocket、业务逻辑
│   ├── api_service.dart       # HTTP 请求、token 刷新、ApiException
│   ├── post_service.dart      # 帖子 + 点赞状态合并
│   ├── chat_push_service.dart # WebSocket /ws/chat（私信推送）
│   ├── presence_service.dart  # WebSocket /ws/presence（在线状态）
│   ├── notification_service.dart
│   ├── memory_service.dart    # AI 记忆功能
│   └── ...
│
├── widgets/                   # 可复用 UI 组件
│   ├── moe_toast.dart         # 顶部弹窗通知
│   ├── moe_loading.dart       # 品牌 Loading 动画
│   ├── moe_input_field.dart   # 统一输入框
│   ├── moe_bottom_bar.dart    # 底部导航栏
│   ├── app_message_widget.dart # 全局 loading 遮罩 + toast 中转
│   └── auth_background.dart   # 登录/注册页背景
│
└── utils/                     # 工具函数
    ├── validators.dart        # 表单校验（email/password/username）
    ├── error_handler.dart     # SnackBar 错误提示（旧方式，新代码用 MoeToast）
    └── config/                # 应用配置
```

> **新增页面位置约定**：放到 `lib/pages/<功能模块>/` 下，并在 `main.dart` 路由表里注册。

## 核心概念

### 1. Widget

Flutter中一切都是Widget，Widget是构建UI的基本单位。

```dart
// 基本Widget示例
Text('Hello World'),
Container(
  child: Text('Hello'),
  padding: EdgeInsets.all(16),
  margin: EdgeInsets.symmetric(horizontal: 8),
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(8),
  ),
),
```

### 2. State

Flutter应用是声明式的，状态变化会触发UI重建。

```dart
// StatefulWidget示例
class Counter extends StatefulWidget {
  @override
  _CounterState createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  void _increment() {
    setState(() {
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: $_count'),
        ElevatedButton(
          onPressed: _increment,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

### 3. Navigator

用于页面导航和路由管理。

```dart
// 导航到新页面
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => SecondPage()),
);

// 返回上一页
Navigator.pop(context);

// 替换当前页面
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => NewPage()),
);
```

### 4. Provider

用于状态管理，推荐使用provider包。

```dart
// 在pubspec.yaml中添加依赖
// dependencies:
//   provider: ^6.0.0

// 创建数据模型
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

// 提供数据
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CounterModel(),
      child: MyApp(),
    ),
  );
}

// 消费数据
class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CounterModel>(
      builder: (context, counter, child) {
        return Text('Count: ${counter.count}');
      },
    );
  }
}
```

## 常用Widget

### 布局Widget
- `Container` - 容器，支持填充、边距、装饰等
- `Row` - 水平布局
- `Column` - 垂直布局
- `Stack` - 堆叠布局
- `ListView` - 列表布局
- `GridView` - 网格布局
- `Expanded` - 扩展填充可用空间
- `Flexible` - 灵活布局

### 交互Widget
- `ElevatedButton` -  elevated按钮
- `TextButton` - 文本按钮
- `OutlinedButton` - 轮廓按钮
- `TextField` - 文本输入框
- `CheckBox` - 复选框
- `Radio` - 单选按钮
- `Switch` - 开关
- `Slider` - 滑块

### 展示Widget
- `Text` - 文本
- `Image` - 图片
- `Icon` - 图标
- `Card` - 卡片
- `AlertDialog` - 对话框
- `SnackBar` - 底部提示

## 网络请求

使用`http`或`dio`包进行网络请求：

```dart
// pubspec.yaml
// dependencies:
//   http: ^1.0.0

import 'package:http/http.dart' as http;

Future<void> fetchData() async {
  final response = await http.get(Uri.parse('https://api.example.com/data'));
  
  if (response.statusCode == 200) {
    // 处理响应
    print(response.body);
  } else {
    // 处理错误
    print('Request failed with status: ${response.statusCode}');
  }
}
```

## 本地存储

使用`shared_preferences`包进行本地存储：

```dart
// pubspec.yaml
// dependencies:
//   shared_preferences: ^2.0.0

import 'package:shared_preferences/shared_preferences.dart';

// 存储数据
Future<void> saveData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('username', 'user123');
  await prefs.setInt('score', 100);
}

// 读取数据
Future<void> loadData() async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username');
  final score = prefs.getInt('score');
  print('Username: $username, Score: $score');
}
```

## 主题和样式

```dart
// 定义主题
final theme = ThemeData(
  primaryColor: Colors.blue,
  accentColor: Colors.green,
  fontFamily: 'Roboto',
  textTheme: TextTheme(
    headline1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    bodyText1: TextStyle(fontSize: 16),
  ),
);

// 使用主题
MaterialApp(
  theme: theme,
  home: MyHomePage(),
);

// 访问主题
Container(
  color: Theme.of(context).primaryColor,
  child: Text(
    'Hello',
    style: Theme.of(context).textTheme.headline1,
  ),
);
```

## 国际化

```dart
// pubspec.yaml
// dependencies:
//   flutter_localizations: 
//     sdk: flutter
//   intl: ^0.17.0

// 在main.dart中配置
MaterialApp(
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('en', ''),
    Locale('zh', ''),
  ],
  home: MyHomePage(),
);

// 使用国际化
Text(AppLocalizations.of(context)!.hello);
```

## 性能优化

1. **使用const构造器**：对于不变的Widget使用const
2. **避免在build方法中创建复杂对象**：将计算移到build方法外
3. **使用ListView.builder**：对于长列表使用builder构造器
4. **使用constraints**：合理使用布局约束
5. **避免过度重建**：使用const和shouldRebuild
6. **使用RepaintBoundary**：减少不必要的重绘
7. **使用Image.cache**：缓存图片

## 调试技巧

1. **使用print**：简单的日志输出
2. **使用debugPrint**：避免日志截断
3. **使用Flutter DevTools**：性能分析和调试
4. **使用断点**：在IDE中设置断点
5. **使用Flutter Inspector**：检查Widget树

## 常见问题

1. **Widget不显示**
   - 检查Widget是否正确添加到树中
   - 检查布局约束
   - 检查可见性设置

2. **状态不更新**
   - 确保使用setState()
   - 检查Provider是否正确配置
   - 检查状态管理逻辑

3. **网络请求失败**
   - 检查网络连接
   - 检查API地址
   - 检查权限配置

4. **性能问题**
   - 使用Flutter DevTools分析性能
   - 优化Widget重建
   - 减少不必要的计算

## 学习资源

- [Flutter官网](https://flutter.dev/docs)
- [Flutter中文网](https://flutter.cn/docs)
- [Flutter实战](https://book.flutterchina.club/)
- [Flutter Widget of the Week](https://www.youtube.com/playlist?list=PLjxrf2q8roU23XGwz3Km7sQZFTdB996iG)
- [Flutter Cookbook](https://flutter.dev/docs/cookbook)