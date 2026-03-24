# 页面开发

## 概述

本项目的页面开发遵循Flutter的页面结构和导航模式，使用MaterialApp作为应用入口，通过Navigator进行页面间的导航。

## 页面结构

### 主页面结构

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moe Social',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
      routes: {
        '/home': (context) => HomePage(),
        '/profile': (context) => ProfilePage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}
```

### 页面生命周期

```dart
class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  void initState() {
    super.initState();
    // 页面初始化时调用
    print('Page initialized');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖变化时调用
    print('Dependencies changed');
  }

  @override
  void dispose() {
    // 页面销毁时调用
    print('Page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Page'),
      ),
      body: Center(
        child: Text('Hello World'),
      ),
    );
  }
}
```

## 页面类型

### 1. 登录页面 (LoginPage)

用户登录界面，包含用户名和密码输入框。

```dart
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 调用登录API
        await AuthService.login(
          _usernameController.text,
          _passwordController.text,
        );

        // 登录成功，导航到首页
        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        // 处理错误
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('登录', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              CustomTextField(
                controller: _usernameController,
                labelText: '用户名',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }
                  return null;
                },
              ),
              CustomTextField(
                controller: _passwordController,
                labelText: '密码',
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  return null;
                },
              ),
              CustomButton(
                text: '登录',
                onPressed: _login,
                loading: _isLoading,
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: Text('注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 2. 注册页面 (RegisterPage)

用户注册界面，包含用户名、密码、邮箱等输入框。

### 3. 首页 (HomePage)

应用的主页面，显示动态、消息等内容。

### 4. 个人资料页面 (ProfilePage)

用户个人资料展示和编辑页面。

### 5. 设置页面 (SettingsPage)

应用设置页面，包含账号、通知、隐私等设置。

### 6. AI聊天页面 (ChatPage)

与AI助手聊天的页面。

### 7. AutoGLM配置页面 (AutoGLMConfigPage)

AutoGLM智能助手的配置页面。

### 8. 签到页面 (CheckinPage)

用户签到获取积分的页面。

### 9. 等级页面 (UserLevelPage)

用户等级和经验值展示页面。

## 导航管理

### 基本导航

```dart
// 导航到新页面
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => NextPage()),
);

// 导航到命名路由
Navigator.pushNamed(context, '/next');

// 返回上一页
Navigator.pop(context);

// 替换当前页面
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => NewPage()),
);

// 返回到指定页面
Navigator.popUntil(context, ModalRoute.withName('/home'));
```

### 带参数的导航

```dart
// 传递参数
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => DetailPage(id: '123'),
  ),
);

// 接收参数
class DetailPage extends StatelessWidget {
  final String id;

  const DetailPage({Key? key, required this.id}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('详情页')),
      body: Center(child: Text('ID: $id')),
    );
  }
}

// 使用命名路由传递参数
Navigator.pushNamed(
  context,
  '/detail',
  arguments: {'id': '123', 'name': '测试'},
);

// 接收命名路由参数
class DetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return Scaffold(
      appBar: AppBar(title: Text('详情页')),
      body: Center(child: Text('ID: ${args['id']}, Name: ${args['name']}')),
    );
  }
}
```

### 导航动画

```dart
// 自定义导航动画
Navigator.push(
  context,
  PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => NextPage(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  ),
);
```

## 页面状态管理

### 局部状态

使用setState管理页面内部状态：

```dart
class CounterPage extends StatefulWidget {
  @override
  _CounterPageState createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _count = 0;

  void _increment() {
    setState(() {
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('计数器')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Count: $_count'),
            ElevatedButton(
              onPressed: _increment,
              child: Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 全局状态

使用Provider管理全局状态：

```dart
// 创建状态模型
class UserModel extends ChangeNotifier {
  User? _user;
  User? get user => _user;

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

// 提供状态
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserModel(),
      child: MyApp(),
    ),
  );
}

// 消费状态
class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserModel>(
      builder: (context, userModel, child) {
        if (userModel.user == null) {
          return LoginPage();
        }
        return Scaffold(
          appBar: AppBar(title: Text('个人资料')),
          body: Center(
            child: Text('欢迎, ${userModel.user!.username}'),
          ),
        );
      },
    );
  }
}
```

## 页面布局

### 响应式布局

```dart
class ResponsivePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            // 移动端布局
            return MobileLayout();
          } else if (constraints.maxWidth < 1200) {
            // 平板布局
            return TabletLayout();
          } else {
            // 桌面布局
            return DesktopLayout();
          }
        },
      ),
    );
  }
}
```

### 自适应布局

```dart
class AdaptivePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          return orientation == Orientation.portrait
              ? PortraitLayout()
              : LandscapeLayout();
        },
      ),
    );
  }
}
```

## 页面性能优化

1. **使用const构造器**：对于不变的Widget使用const
2. **避免在build方法中创建复杂对象**：将计算移到build方法外
3. **使用ListView.builder**：对于长列表使用builder构造器
4. **使用RepaintBoundary**：减少不必要的重绘
5. **使用CachedNetworkImage**：缓存网络图片
6. **避免过度使用InheritedWidget**：减少重建
7. **使用FutureBuilder和StreamBuilder**：合理处理异步数据

## 页面测试

### 单元测试

```dart
void main() {
  testWidgets('Login page widget test', (WidgetTester tester) async {
    // 构建登录页面
    await tester.pumpWidget(MaterialApp(home: LoginPage()));

    // 验证页面元素
    expect(find.text('登录'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);

    // 模拟用户输入
    await tester.enterText(find.byType(TextField).first, 'testuser');
    await tester.enterText(find.byType(TextField).last, 'password123');

    // 模拟点击登录按钮
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // 验证登录逻辑
    // ...
  });
}
```

### 集成测试

```dart
void main() {
  group('App integration tests', () {
    testWidgets('Full login flow', (WidgetTester tester) async {
      // 构建应用
      await tester.pumpWidget(MyApp());

      // 验证初始页面是登录页
      expect(find.text('登录'), findsOneWidget);

      // 输入用户名和密码
      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'password123');

      // 点击登录
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // 验证导航到首页
      expect(find.text('首页'), findsOneWidget);
    });
  });
}
```

## 常见问题

1. **页面导航问题**
   - 检查路由是否正确配置
   - 确保Navigator上下文正确
   - 检查页面是否正确构建

2. **页面状态丢失**
   - 使用Provider等状态管理方案
   - 考虑使用PageStorage保存状态
   - 避免在build方法中重置状态

3. **页面性能问题**
   - 检查是否有不必要的重建
   - 优化列表和网格的渲染
   - 减少复杂计算和网络请求

4. **页面布局问题**
   - 检查布局约束
   - 使用LayoutBuilder和OrientationBuilder
   - 考虑不同屏幕尺寸

5. **页面生命周期问题**
   - 正确使用initState和dispose
   - 避免在dispose后访问context
   - 处理异步操作的取消

## 最佳实践

1. **页面职责单一**：每个页面只负责一个主要功能
2. **状态管理清晰**：使用合适的状态管理方案
3. **导航逻辑明确**：建立清晰的导航流程
4. **布局响应式**：适应不同屏幕尺寸
5. **性能优化**：避免不必要的重建和计算
6. **代码组织**：合理组织页面代码结构
7. **测试覆盖**：为页面编写单元测试和集成测试
8. **错误处理**：妥善处理异常和错误情况

## 总结

页面开发是Flutter应用的核心部分，通过合理的页面结构、导航管理和状态管理，可以构建出流畅、美观的用户界面。在开发过程中，应注重代码质量、性能优化和用户体验，确保应用的稳定性和可用性。