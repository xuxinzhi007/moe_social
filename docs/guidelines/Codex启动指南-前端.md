# Codex Startup Guide（前端）

## 两套前端（改代码前先确认目录）

| 目录 | 技术栈 | 规范 |
|------|--------|------|
| `lib/` | Flutter + Provider | 本文件下文 + `.cursorrules` 萌系 UI |
| `moe-admin/` | React + Vite + TypeScript | `moe-admin/src/styles/moe-admin-theme.css`、`moe-admin/docs/admin-design-system.md`（设计参考） |

管理台 **不** 使用 Flutter 组件；改动 `moe-admin/` 时不要套用 `lib/widgets` 约定。交付前在 `moe-admin/` 执行 `npm run build`。

---

本项目 App 前端位于 `lib/`，基于 **Flutter + Provider**。默认沿用现有页面分域与组件复用方式，不引入与当前工程冲突的新架构。

## 项目结构（前端）

- `lib/main.dart`：应用入口与全局初始化
- `lib/app/app_routes.dart`：命名路由（重模块 `deferred import` 懒加载）
- `lib/app/main_shell.dart`：底部 Tab 主框架
- `lib/pages/<domain>/`：按业务域组织页面（auth/feed/profile/commerce/...）
- `lib/widgets/`：可复用 UI 组件
- `lib/services/`：接口调用与业务服务封装
- `lib/models/`：数据模型
- `lib/providers/`：全局状态管理（Provider）
- `analysis_options.yaml`：Dart/Flutter lint 约束
- `pubspec.yaml`：依赖与 assets 配置

## 默认工作规则

1. 新页面优先放 `lib/pages/<domain>/`，可复用 UI 抽到 `lib/widgets/`。
2. 网络请求优先复用 `lib/services/` 现有封装，不在页面内堆积请求细节。
3. 涉及后端字段/接口变更时，先确认 `backend/` 契约，再同步 `models + services + pages`。
4. 除非明确需求，不重构无关页面和公共组件。

## 技能使用顺序（前端规范化）

前端任务建议使用以下技能策略：

1. `implementation-guardrails`：先定义可验证结果，保持最小改动和清晰边界。
2. `security-best-practices`（条件触发）：仅在你明确要求安全加固/安全报告时启用。
3. `git-commit`（提交前触发）：按 Conventional Commits 生成提交信息。

补充：
- `gh-fix-ci`：用于修复 GitHub Actions 失败。
- `gh-address-comments`：用于处理 PR 评论。
- `security-threat-model`：仅在你明确要求威胁建模时启用。

## UI 与交互约定（项目当前风格）

- 页面背景优先使用现有萌系浅色基调（参考 `.cursorrules`）。
- 保持圆角、柔和阴影、Rounded 图标等现有视觉语言一致。
- 列表/卡片动效优先复用现有组件（如 `FadeInUp` 等），不要重复造轮子。

## Flutter 开发约定（结合项目现状）

- 异步回调更新 UI 前先判断 `mounted`。
- 全局状态优先 `Provider`，局部瞬时状态使用 `setState`。
- 错误提示面向用户可读，避免直接暴露底层异常细节。
- 复用当前目录命名与 import 风格，不引入突兀的新分层。
- `pubspec.yaml` 中 assets 已按 `assets/` 根目录声明，避免重复声明子目录导致打包冲突。

## 启动与编译性能（已落地约定）

- **入口**：`main()` 立即 `runApp`，`RiveBootstrap.ensureInitialized()` 后台执行，不阻塞首帧。
- **Splash**：`StartupManager` 只 `await` 关键任务（API Config / Auth / Theme）；通知、Push 等后台跑。
- **重页面懒加载**：扫码、扭蛋、VIP/钱包、Agora 通话等走 `lib/app/app_routes.dart` 的 `deferred import`；新增重依赖页面请沿用 `DeferredRoute`。
- **Web**：`FloatingVirtualAvatarHost` 跳过 Rive；开发 Web 时优先 `flutter run -d chrome`，并保持进程不退出用 Hot Reload。
- **环境**：本机 `flutter` 冷启动可能数分钟，可先 `flutter --version` 预热。

## 修改前优先检查

- `analysis_options.yaml`
- `pubspec.yaml`
- 目标页面同目录已有实现（例如 `lib/pages/<domain>/` 下同类页面）
- 相关 `lib/services/` 与 `lib/models/`（确保字段映射一致）

## 交付前检查（最少）

```bash
dart format $(git diff --name-only -- '*.dart')
flutter analyze
```

如改动包含复杂交互，补充最小可复现手动测试：加载态、成功态、失败态。

## 重要提醒

- 先对齐现有页面和组件写法，再扩展新功能。
- 前端改动不要混入后端实现文件。
- 保持 UI 风格统一比“单页看起来更炫”更重要。
