# Frontend UX Ideation — 2026-05-29

## 范围

- 目录：`lib/`（Flutter App）
- 重点域：主框架 Tab（首页 / 同好 / 社区 / 探索 / 我的）、设置、私信、会员商业化
- 方法：规范对照 + 代码扫描 + 高频页抽样
- 静态检查：`flutter analyze lib/` → 0 error（info 主要为历史 `withOpacity`）

## 摘要

项目已有较完整的「萌系」组件层。**P0 地基已落地**（2026-05-29）：`MoeTokens` / `MoeTheme` extension、`MoeEmptyState`、懒加载品牌化、`settings_page` 统一 `MoeMenuCard`。剩余硬编码色迁移与消息域空态为 **P1**。

---

## 错误文案统一管理（2026-05-29 新增）

**SSOT**：`lib/utils/moe_error_copy.dart`  
**UI 组件**：`lib/widgets/moe_error_state.dart`  
**Toast 入口**：`lib/utils/error_handler.dart` → `MoeErrorCopy.toast()`

### 用法

```dart
// 页面错误态
MoeErrorState.fromError(
  error,
  scene: MoeErrorScene.feed, // contacts / community / profile …
  onRetry: _reload,
);

// Toast
MoeToast.error(context, MoeErrorCopy.toast(error, scene: MoeErrorScene.profile));
```

### 已接入页面

| 页面 | scene |
|------|-------|
| `friends_page` | `contacts` |
| `home_page` | `feed` |
| `interest_groups_page` | `community` |
| `profile_page` | `profile`（Toast） |
| `followers_page` / `following_page` | `followers` / `following` |
| `deferred_route` | `pageLoad` |

### 统一后的网络错误文案

- 标题：按场景（如「暂时没能加载同好」「暂时没能加载动态」）
- 副文案：**网络不太稳定，请检查连接后重试**（不再出现「服务器是否开启」）

---


| # | 项 | 状态 | 涉及文件 |
|---|-----|------|----------|
| 1 | 设计 token SSOT | ✅ 已建 | `lib/theme/moe_tokens.dart`、`lib/theme/moe_theme_extension.dart` |
| 2 | ThemeProvider 接入 extension | ✅ | `lib/providers/theme_provider.dart`（`extensions: [MoeTheme]`，按钮 elevation 0） |
| 3 | 设置页统一 MoeMenuCard | ✅ | `lib/pages/settings/settings_page.dart`（含搜索结果的 ListTile 已移除） |
| 4 | 懒加载品牌化 + 可重试 | ✅ | `lib/app/deferred_route.dart` |
| 5 | 全局空态组件 | ✅ | `lib/widgets/moe_empty_state.dart` |
| 6 | AI token 合并 | ✅ | `lib/widgets/ai/ai_brand_tokens.dart` → 委托 `MoeTokens` |
| 7 | 菜单卡片 token 化 | ✅ | `lib/widgets/moe_menu_card.dart` |
| 8 | 页面壳别名 | ✅ | `lib/theme/moe_page_scaffold.dart`（`AdaptivePageScaffold` 默认背景改 `MoeTokens`） |
| 9 | 全库硬编码色迁移 | ⏳ P1 | 70+ 文件仍硬编码，新代码应读 `MoeTheme.of(context)` |

### 新增 / 修改文件清单

```
lib/theme/moe_tokens.dart              [新增]
lib/theme/moe_theme_extension.dart     [新增]
lib/theme/moe_page_scaffold.dart       [新增]
lib/widgets/moe_empty_state.dart       [新增]
lib/providers/theme_provider.dart      [修改]
lib/app/deferred_route.dart            [修改]
lib/pages/settings/settings_page.dart  [修改]
lib/widgets/moe_menu_card.dart         [修改]
lib/widgets/ai/ai_brand_tokens.dart    [修改]
lib/widgets/layout/adaptive_page_scaffold.dart [修改]
```

### 受影响的用户路径（需人工验收）

| 路径 | 操作 | 预期 |
|------|------|------|
| **设置** | 我的 → 设置 | 「聊天与隐私」「常规设置」卡片与「账户与安全」等同风格；Switch 可切换并 Toast |
| **设置搜索** | 设置顶栏搜索任意项 | 结果为 `MoeMenuCard` 单条，点击可跳转 |
| **虚拟助手** | 设置 → 虚拟助手行点击 / Switch | 开关有效；点击行进入虚拟形象设置 |
| **懒加载页** | 进入 VIP 中心 / 钱包 / 扫码 / 扭蛋等 deferred 路由 | 加载为紫色 `MoeLoading` + 文案；失败显示友好空态 +「重试」 |
| **主题色** | 设置 → 外观 → 换主题颜色 | AppBar/按钮/Switch  thumb 随主色变化（卡片渐变仍部分硬编码，属 P1） |
| **AI 探索** | 探索 Tab | 背景色与全局 `F5F7FA` 一致（`AiBrandTokens.pageBackground` 已对齐） |

### 验收命令

```bash
cd /Users/xuxinzhi/Documents/gowork/moe_social
dart format lib/theme lib/widgets/moe_empty_state.dart lib/app/deferred_route.dart \
  lib/providers/theme_provider.dart lib/pages/settings/settings_page.dart \
  lib/widgets/moe_menu_card.dart lib/widgets/ai/ai_brand_tokens.dart \
  lib/widgets/layout/adaptive_page_scaffold.dart lib/theme/moe_page_scaffold.dart
flutter analyze lib/theme lib/widgets/moe_empty_state.dart lib/app/deferred_route.dart \
  lib/providers/theme_provider.dart lib/pages/settings/settings_page.dart \
  lib/widgets/moe_menu_card.dart lib/widgets/ai/ai_brand_tokens.dart \
  lib/widgets/layout/adaptive_page_scaffold.dart
```

---

## 发现（按优先级）

### P0 — 已完成项见上表

| # | 问题 | 状态 |
|---|------|------|
| 1 | 设计 token 分散 | ✅ 基础设施；全库迁移 ⏳ P1 |
| 2 | 设置页 ListTile 混用 | ✅ |
| 3 | 懒加载路由品牌化 | ✅ |
| 4 | 主题定制 vs 硬编码 | ⏳ extension 已接入，页面分批替换 |

### P1（下一步）

| # | 问题 | 位置 | 建议 |
|---|------|------|------|
| 5 | 加载指示器不统一 | `conversations_page.dart` 等 | `MoeLoading` / `MoeSmallLoading` |
| 6 | 会话空态无 CTA | `conversations_page.dart` | 使用 `MoeEmptyState` + 跳转同好/探索 |
| 7 | 错误重试按钮 Material 化 | `conversations_page.dart` | `CustomButton` |
| 8 | 账户安全 sheet 内 ListTile | `account_security_module.dart` | `MoeMenuCard` 紧凑变体 |
| 9 | `friends_page` 过大 | `friends_page.dart` | 拆 widget |
| 10 | 首页背景 | `home_page.dart` | `MoePageScaffold` |

### P2

- `FadeInUp` 覆盖不均
- 全库 `withOpacity` → `withValues`
- 深色模式硬编码浅色验证

---

## 复用性评估（2026-05-29）

| 资产 | 落地情况 |
|------|----------|
| `MoeTokens` / `MoeTheme` | 新 SSOT；`ThemeProvider` 已注册 |
| `MoeEmptyState` | 已用于 `deferred_route`；待推广至会话等 |
| `MoePageScaffold` | 别名已有；页面 Adoption 为 P1 |
| `MoeMenuCard` | 设置域已统一；全库仍有 ~20 处 `ListTile` |
| `AiBrandTokens` | 已委托 `MoeTokens`，减少双轨 |

---

## 建议的下一轮 CE

1. **`/ce-work`** — P1：`conversations_page` 空态 + 加载统一
2. **`/ce-plan`** — 硬编码色分批迁移计划（commerce → profile → community）

---

## 附录

- P0 验证：`flutter analyze` 针对改动文件 **0 error**（2026-05-29）
- 未覆盖：`moe-admin/`
