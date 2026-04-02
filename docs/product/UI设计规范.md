# Moe Social UI Design Guide

本指南定义了 **Moe Social** 项目的视觉风格和 UI 规范。所有新页面的开发都应遵循此规范，以保持应用风格的高度统一。

## 1. 核心设计理念

*   **风格**: Moe (萌系) / Dreamy (梦幻) / Soft (柔和)
*   **关键词**: 圆润、悬浮、渐变、呼吸感
*   **交互**: 灵动、弹性反馈

---

## 2. 色彩系统 (Color System)

采用了清新明亮的糖果色系。

### 主色调 (Primary Palette)
*   **Lavender (薰衣草紫)**: `#7F7FD5` (主要品牌色，用于按钮、高亮、图标)
*   **Sky Blue (天空蓝)**: `#86A8E7` (辅助色，用于渐变过渡)
*   **Mint (薄荷绿)**: `#91EAE4` (点缀色，用于背景装饰)

### 中性色 (Neutrals)
*   **Background (背景灰)**: `#F5F7FA` (用于页面底色，比纯白更有质感)
*   **Card White (卡片白)**: `#FFFFFF` (纯白，用于内容承载)
*   **Text Main (正文黑)**: `Colors.black87`
*   **Text Sub (次级灰)**: `Colors.grey[600]`

### 渐变应用 (Gradients)
用于大面积背景（如 Header、登录页背景）：
```dart
LinearGradient(
  colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

---

## 3. 布局模式 (Layout Patterns)

### 3.1 沉浸式背景 + 悬浮卡片
适用于：登录、注册、忘记密码、个人中心头部。

*   **背景**: 顶部 35%-40% 高度的渐变背景，底部圆角 `borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), ...)`。
*   **内容**: 使用 `Stack` 布局，内容包裹在 `Positioned` 中。
*   **卡片**: 表单或主要信息包裹在白色 `Container` 中，添加柔和阴影。

### 3.2 列表页面
适用于：动态流、评论、通知。

*   **背景**: 使用 `#F5F7FA`。
*   **列表项**: 每个 Item 是一个独立的卡片，有圆角 (16-20px) 和白色背景。

---

## 4. 组件规范 (Component Specs)

### 4.1 按钮 (Buttons)
*   **形状**: 全圆角 (StadiumBorder) 或大圆角矩形 (BorderRadius.circular(25))。
*   **高度**: 50px。
*   **样式**:
    ```dart
    ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF7F7FD5),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      elevation: 5, // 悬浮感
      shadowColor: Color(0xFF7F7FD5).withOpacity(0.4), // 更有质感的彩色阴影
    )
    ```

### 4.2 输入框 (Text Fields)
*   **边框**: 圆角 15px。
*   **填充**: 启用 `filled: true`，颜色 `Colors.grey[50]`。
*   **状态**: 聚焦时边框变为主色 `#7F7FD5`。

### 4.3 图标 (Icons)
*   优先使用 `_rounded` 后缀的 Material 图标（如 `Icons.favorite_rounded`）。
*   在列表中，图标通常带有浅色透明背景容器。

---

## 5. 动画规范 (Animations)

页面核心元素（标题、卡片、列表项）应使用 `FadeInUp` 组件进行入场动画。

```dart
FadeInUp(
  duration: Duration(milliseconds: 800),
  delay: Duration(milliseconds: 100 * index), // 列表项交错延迟
  child: ...
)
```

---

## 6. 代码片段示例

### 通用背景装饰圆
```dart
Positioned(
  top: -50,
  right: -50,
  child: Container(
    width: 200,
    height: 200,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      shape: BoxShape.circle,
    ),
  ),
)
```

### 通用阴影配置
```dart
boxShadow: [
  BoxShadow(
    color: Colors.grey.withOpacity(0.1), // 或主色.withOpacity(0.3)
    blurRadius: 20,
    offset: Offset(0, 10),
  ),
]
```

