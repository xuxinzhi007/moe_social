# Moe Social · Flutter Web 自动化测试

## ⚠️ 重要说明：Flutter Web 的测试限制

Flutter Web 对传统 Web 自动化测试工具（如 Playwright）**天然不友好**，原因是：

| 问题 | 说明 |
|------|------|
| **CanvasKit 渲染** | Flutter 默认把整个 UI 画在 `<canvas>` 上，DOM 中没有 `<input>`、`<button>` 等元素 |
| **HTML 渲染器** | Flutter 的 HTML 渲染器会生成自定义标签（如 `<flutter-view>`），不是标准 HTML 组件 |
| **无 DOM 可访问性** | Playwright 的 `getByText()`、`getByRole()`、`locator()` 都无法定位 Flutter Widget |

**结论**：Playwright 无法直接点击 Flutter 的按钮、输入框。**这不是 Playwright 的问题，是 Flutter Web 架构决定的。**

---

## ✅ 可靠方案：视觉回归测试

我们采用 **截图对比** 作为主要验证手段：

```
同一页面每次渲染 → 截图哈希相同 ✅
不同页面（登录 vs 注册）→ 截图哈希不同 ✅
页面崩溃/白屏 → 截图过小 → 被检测到 ✅
```

**优势**：
- 完全不依赖 DOM 结构
- 基于视觉输出，稳定可靠
- 能检测到渲染崩溃、样式变化
- 能对比两次构建的差异

---

## 快速开始

### 1. 安装依赖

```bash
cd e2e
npm install
```

### 2. 启动 Flutter Web（任选一种）

```bash
# 方式 A：开发模式（推荐，先确认页面能正常打开）
cd .. && flutter run -d chrome --web-port 9900

# 方式 B：Release 构建 + 静态服务（最稳定，无热重载干扰）
flutter build web --release
cd build/web && python3 -m http.server 9900
```

### 3. 运行测试

```bash
cd e2e

# 运行全部测试
npm test

# 运行视觉回归测试（推荐）
npx playwright test specs/visual-regression.spec.ts

# 可视化运行（看到浏览器）
npx playwright test specs/visual-regression.spec.ts --headed
```

---

## 测试套件说明

| 文件 | 测试内容 |
|------|---------|
| `visual-regression.spec.ts` | ✅ 主测试套件：渲染验证 + 页面差异 + 稳定性 + 基准对比 |
| `smoke.spec.ts` | 快速冒烟测试（遍历所有页面，检查是否崩溃） |
| `comprehensive.spec.ts` | 完整测试（截图对比 + 响应式 + 性能） |

---

## 视觉回归测试能检测什么

### ✅ 能检测到
- 页面白屏/崩溃
- 不同页面的渲染差异
- 同一页面渲染的稳定性（5次刷新应该相同）
- 加载时间过长
- 移动端 vs 桌面端的响应式差异
- 与历史版本的视觉回归

### ❌ 检测不到（需要人工或 Flutter integration_test）
- 按钮点击是否真的触发了业务逻辑
- 表单输入是否正确提交
- 动画是否流畅
- 具体的 UI 细节（如文字颜色、字体大小）

---

## 如果需要测试「按钮点击」等交互

### 方案 1：Flutter integration_test（最可靠）
Flutter 官方提供的集成测试，运行在真实的 Flutter 引擎中。

```dart
// integration_test/login_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('登录流程', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 可以直接找到 Flutter 的 Widget
    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
  });
}
```

运行：
```bash
flutter test integration_test/login_test.dart
```

### 方案 2：使用 Patrol（Flutter 专用测试框架）
```bash
flutter pub add patrol
patrol test
```

### 方案 3：接受坐标点击的局限性
如果必须用 Playwright，可以按坐标点击（不推荐，维护困难）：
```typescript
// 点击"登录"按钮的大致位置
await page.mouse.click(720, 650);
await page.waitForTimeout(1000);
const hash = imgHash(await page.screenshot());
// 检查点击后截图是否有变化
```

---

## 项目结构

```
e2e/
├── Makefile
├── package.json
├── playwright.config.ts
├── README.md
├── routes.ts                   ← 页面路由定义
├── pages/
│   └── smoke-utils.ts         ← 工具函数
└── specs/
    ├── visual-regression.spec.ts  ← ✅ 主测试套件（推荐）
    ├── smoke.spec.ts           ← 快速冒烟测试
    ├── comprehensive.spec.ts   ← 完整测试（含截图）
    ├── diagnose.spec.ts        ← 诊断工具
    └── route-debug.spec.ts    ← 路由调试
```

---

## 常见问题

**Q: 截图只有 5-6KB，正常吗？**
A: 正常。Flutter Web 的页面相对简洁，截图压缩后就是这个大小。只要不是 2-3KB 以下的白屏就行。

**Q: 为什么所有页面的截图哈希都一样？**
A: 这是 Flutter 路由没有正确响应 URL 的表现。检查：
   1. 是否是 debug 模式（热重载干扰）
   2. 是否需要配置 `usePathUrlStrategy`
   3. 尝试 release 模式：`flutter build web --release`

**Q: 如何让 Playwright 能点击按钮？**
A: Flutter Web 无法直接做到。可以：
   1. 使用 Flutter 的 `integration_test`（最可靠）
   2. 使用 Patrol 框架
   3. 接受坐标点击（不推荐，维护困难）
