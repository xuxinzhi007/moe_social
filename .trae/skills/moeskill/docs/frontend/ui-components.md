# UI组件库

## 概述

本项目包含一系列自定义UI组件，用于构建统一、美观的用户界面。这些组件遵循Material Design设计规范，同时添加了项目特有的风格元素。

## 核心组件

### 1. 按钮组件

#### CustomButton

自定义按钮组件，支持多种样式和状态。

```dart
CustomButton(
  text: '点击按钮',
  onPressed: () {},
  type: ButtonType.primary, // primary, secondary, outline, text
  size: ButtonSize.medium, // small, medium, large
  loading: false,
  disabled: false,
);
```

#### 特性
- 支持多种按钮类型：主要按钮、次要按钮、轮廓按钮、文本按钮
- 支持不同尺寸：小、中、大
- 内置加载状态和禁用状态
- 自定义颜色和样式

### 2. 输入组件

#### CustomTextField

自定义文本输入框，支持验证和错误提示。

```dart
CustomTextField(
  controller: _controller,
  labelText: '用户名',
  hintText: '请输入用户名',
  obscureText: false,
  validator: (value) {
    if (value == null || value.isEmpty) {
      return '请输入用户名';
    }
    return null;
  },
  onChanged: (value) {
    // 处理输入变化
  },
);
```

#### 特性
- 支持标签、提示文本
- 内置表单验证
- 错误状态和提示
- 密码输入模式
- 自定义输入类型

### 3. 布局组件

#### Card

卡片组件，用于展示内容块。

```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text('卡片标题'),
        Text('卡片内容'),
      ],
    ),
  ),
);
```

#### 特性
- 阴影效果
- 圆角边框
- 可点击效果
- 自定义颜色和样式

### 4. 头像组件

#### AvatarImage

用户头像组件，支持网络图片和默认头像。

```dart
AvatarImage(
  url: 'https://example.com/avatar.jpg',
  size: 50,
  placeholder: Icons.person,
);
```

#### 特性
- 支持网络图片
- 圆形裁剪
- 默认头像
- 加载状态

### 5. 动画组件

#### FadeInUp

淡入上移动画组件。

```dart
FadeInUp(
  child: Text('动画文本'),
  duration: Duration(milliseconds: 500),
  delay: Duration(milliseconds: 100),
);
```

#### 特性
- 可配置动画时长
- 支持延迟启动
- 可嵌套使用

### 6. 选择器组件

#### GenderSelector

性别选择器组件。

```dart
GenderSelector(
  selectedGender: _gender,
  onGenderSelected: (gender) {
    setState(() {
      _gender = gender;
    });
  },
);
```

#### ColorSelector

颜色选择器组件。

```dart
ColorSelector(
  selectedColor: _color,
  colors: [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
  ],
  onColorSelected: (color) {
    setState(() {
      _color = color;
    });
  },
);
```

### 7. 徽章组件

#### AchievementBadgeDisplay

成就徽章展示组件。

```dart
AchievementBadgeDisplay(
  badge: AchievementBadge(
    id: '1',
    name: '初学者',
    description: '完成第一个任务',
    icon: Icons.star,
    color: Colors.yellow,
  ),
);
```

### 8. 消息组件

#### AppMessageWidget

应用消息提示组件。

```dart
AppMessageWidget(
  message: '操作成功',
  type: MessageType.success, // success, error, info, warning
  duration: Duration(seconds: 3),
);
```

### 9. 底部导航栏

#### MoeBottomBar

自定义底部导航栏。

```dart
MoeBottomBar(
  currentIndex: _currentIndex,
  onTap: (index) {
    setState(() {
      _currentIndex = index;
    });
  },
  items: [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: '首页',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat),
      label: '聊天',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: '我的',
    ),
  ],
);
```

### 10. 加载组件

#### 加载指示器

```dart
// 全屏加载
LoadingProvider.loading(context);

// 按钮加载
CustomButton(
  text: '提交',
  loading: true,
  onPressed: () {},
);
```

## 主题和样式

### 颜色系统

```dart
// 主色调
Color primaryColor = Color(0xFF4A90E2);
Color secondaryColor = Color(0xFF50E3C2);

// 功能色
Color successColor = Color(0xFF4CD964);
Color errorColor = Color(0xFFFF3B30);
Color warningColor = Color(0xFFFF9500);
Color infoColor = Color(0xFF5AC8FA);

// 中性色
Color backgroundColor = Color(0xFFF2F2F7);
Color surfaceColor = Color(0xFFFFFFFF);
Color textPrimary = Color(0xFF000000);
Color textSecondary = Color(0xFF8E8E93);
```

### 字体系统

```dart
// 标题字体
TextStyle headline1 = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: textPrimary,
);

// 正文字体
TextStyle bodyText1 = TextStyle(
  fontSize: 16,
  color: textPrimary,
);

// 辅助字体
TextStyle caption = TextStyle(
  fontSize: 12,
  color: textSecondary,
);
```

## 使用指南

### 导入组件

```dart
import 'package:moe_social/widgets/custom_button.dart';
import 'package:moe_social/widgets/custom_text_field.dart';
```

### 组件使用最佳实践

1. **保持一致性**：在整个应用中使用相同的组件样式
2. **遵循设计规范**：使用统一的颜色、字体和间距
3. **响应式设计**：考虑不同屏幕尺寸
4. **可访问性**：确保组件对所有用户可访问
5. **性能优化**：避免过度使用复杂动画和嵌套组件

### 自定义组件

如果现有组件不能满足需求，可以创建自定义组件：

```dart
class MyCustomComponent extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const MyCustomComponent({
    Key? key,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(title),
      ),
    );
  }
}
```

## 常见问题

1. **组件样式不一致**
   - 检查是否使用了统一的主题
   - 确保组件参数设置正确

2. **组件布局问题**
   - 检查父容器的约束
   - 使用Expanded或Flexible调整布局

3. **组件性能问题**
   - 避免在build方法中创建复杂对象
   - 使用const构造器
   - 考虑使用ListView.builder等高效组件

4. **组件状态管理**
   - 使用Provider或其他状态管理方案
   - 避免过度使用setState

## MoeToast 使用规范

### 重要：context 必须在 Navigator Overlay 内部

`MoeToast` 通过 `Overlay.maybeOf(context)` 查找 Overlay 并插入通知条目。**context 必须来自某个路由页面内部**（即 Navigator 管理的页面），否则找不到 Overlay，toast 会静默失败（只打印日志，不显示）。

#### 正确用法 ✅

```dart
// 在页面的 build/callback 里直接使用页面的 context
MoeToast.success(context, '操作成功');

// 导航前先弹 toast，再跳转（toast 已插入 Overlay，跳转后依然可见）
MoeToast.success(context, '登录成功！');
Navigator.pushReplacementNamed(context, '/home');
```

#### 错误用法 ❌

```dart
// ❌ navigatorKey.currentContext 是 Navigator 自身的 context，在 Overlay 上方，找不到 Overlay
MoeToast.success(AuthService.navigatorKey.currentContext!, '...');

// ❌ MaterialApp.builder 中的 context 同样在 Navigator 上方
// AppMessageWidget 里的 Overlay.maybeOf(context) 也会返回 null
loadingProvider.setSuccess('...');  // 经 AppMessageWidget 转发，同样失败

// ❌ pushReplacementNamed 返回的 Future 在目标页被 pop 时才完成，不是导航完成时
Navigator.pushReplacementNamed(context, '/home').then((_) {
  MoeToast.success(...);  // 永远不会在正常流程里执行
});
```

#### 登录/注册等跨页面通知的正确模式

```dart
// 登录成功：先 toast，再跳转
onSuccess: (result) {
  MoeToast.success(context, '欢迎回来！(｡♥♥｡)');
  Navigator.pushReplacementNamed(context, '/home');
}

// 注册成功：先 toast，再 pop
onSuccess: (result) {
  MoeToast.success(context, '欢迎加入 Moe Social！(≧∇≦)/');
  Navigator.pop(context);
}
```

---

## 总结

本项目的UI组件库提供了一套统一、美观的界面元素，帮助开发者快速构建高质量的用户界面。通过使用这些组件，可以确保应用的视觉一致性和用户体验的连贯性。

在开发过程中，应优先使用现有组件，并遵循设计规范，以保持应用的整体风格统一。