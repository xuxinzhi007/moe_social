# Frontend UX Ideation — 2026-05-29

## 范围

- 目录：`lib/`（Flutter App）
- 重点域：主框架 Tab（首页 / 同好 / 社区 / 探索 / 我的）、设置、私信、会员商业化
- 方法：规范对照 + 代码扫描 + 高频页抽样
- 静态检查：改动域 `flutter analyze` → **0 error**（info 为历史 `avoid_print` 等）

## 摘要

项目已有较完整的「萌系」组件层。**P0–P4（文档主战场）已完成**：

- 设计 token / 错误文案 SSOT、设置与会话域统一
- 全库 `withOpacity` → `withValues`（0 残留）
- 五大 Tab + 商业化核心页主色/背景跟 `MoeTheme`
- `community_posts_feed` 错误态统一

**P5 待续**（文档范围外深域）：AI 聊天（`ollama_chat_page` 等）、游戏/AutoGLM、`edit_profile_page`、`MoePageScaffold` 全页 adoption、`friends_page` 好友卡片继续拆分。

---

## 完成度总览

| 阶段 | 状态 | 说明 |
|------|------|------|
| P0 地基 | ✅ | Token、Theme、MoeMenuCard、MoeEmptyState、deferred 品牌化 |
| P1 主框架痛点 | ✅ | 会话/设置/我的 loading & 错误；账户安全 sheet |
| P2 动效 & opacity | ✅ | 76 文件 opacity 迁移；主 Tab 页头 FadeInUp；深色背景 |
| P3 主 Tab token 化 | ✅ | home / friends / profile / community / discover 主色清零* |
| P4 商业化 & 讨论流 | ✅ | vip/wallet/recharge/gacha/order；`community_posts_feed` 错误态 |
| P5 深域 | ⏳ | AI/游戏/编辑资料等 ~30 文件仍有 `0xFF7F7FD5` |

\*主 Tab 页面内按钮/渐变已改用 `_moe.primary`；子页（发帖、评论）未纳入 P4。

---

## 「我的」页加载行为说明

### 现象（历史，已修复）

曾出现全屏「正在加载个人信息…」长时间阻塞；根因为绕过 `AuthService` 缓存 + 独有全屏文案。

### 当前逻辑（`lib/pages/profile/profile_page.dart`）

| 阶段 | 行为 |
|------|------|
| **用户信息** | `AuthService.getUserInfo()`：本地缓存优先 |
| **首屏 UI** | 无缓存：AppBar + 居中 `MoeLoading`（与同好页一致） |
| **后台** | 成就/VIP/统计并行；AppBar 小 spinner |
| **下拉刷新** | `forceRefresh: true`，有缓存不挡全屏 |
| **失败** | 无缓存 → `MoeErrorState`；有缓存 → Toast |

---

## 错误文案统一管理

**SSOT**：`lib/utils/moe_error_copy.dart`  
**UI**：`lib/widgets/moe_error_state.dart`  
**Toast**：`lib/utils/error_handler.dart` → `MoeErrorCopy.toast()`

### 已接入页面

| 页面 | scene |
|------|-------|
| `friends_page` | `contacts` |
| `home_page` | `feed` |
| `interest_groups_page` | `community` |
| **`community_posts_feed`** | **`community`** |
| `profile_page` | `profile`（Toast） |
| `followers_page` / `following_page` | `followers` / `following` |
| `conversations_page` | `messages` |
| `deferred_route` | `pageLoad` |

### 统一网络副文案

**网络不太稳定，请检查连接后重试**

---

## P0 基础设施

| # | 项 | 状态 |
|---|-----|------|
| 1 | `MoeTokens` / `MoeTheme` | ✅ |
| 2 | ThemeProvider extension | ✅ |
| 3 | 设置页 `MoeMenuCard` | ✅ |
| 4 | `deferred_route` 品牌化 | ✅ |
| 5 | `MoeEmptyState` | ✅ |
| 6 | `AiBrandTokens` → `MoeTokens` | ✅ |
| 7 | `moe_menu_card` token 化 | ✅ |
| 8 | `MoePageScaffold` 别名 | ✅ 定义；页面 adoption ⏳ P5 |
| 9 | 全库硬编码色 | ✅ 主 Tab + commerce；⏳ AI/游戏等深域 |

---

## P1–P4 明细

### P1（✅）

| # | 问题 | 状态 |
|---|------|------|
| 5–8 | 会话加载/空态/错误；账户安全 sheet | ✅ |
| 9 | `friends_page` 过大 | ⏳ 已拆 3 widget（~400 行）；主文件仍 ~1670 行 |
| 10 | 首页背景 | ✅ `MoeTheme.pageBackground` |
| 11 | 我的首屏 loading | ✅ 缓存优先 + 与同好一致 |

### P2（✅）

| # | 项 | 说明 |
|---|-----|------|
| 12 | `withOpacity` → `withValues` | 全库 0 残留 |
| 13 | `FadeInUp` | 社区/探索页头 + 首页快捷区；`MoeTokens.motion*` |
| 14 | 深色背景 | 五大 Tab + 圈子流 `MoeTheme.pageBackground` |

### P3（✅）

| # | 项 | 说明 |
|---|-----|------|
| 15 | 主 Tab 主色 | `home` / `friends` / `profile` / `community` / `discover` 无 `0xFF7F7FD5` |
| 16 | `friends_page` 拆分 | `add_friend_bottom_sheet`、`friends_hub_tab_strip`、`friends_logged_out_body` |
| 17 | 圈子流 token | `interest_groups_page`、`community_posts_feed` RefreshIndicator |

### P4（✅ 2026-05-29）

| # | 项 | 文件 |
|---|-----|------|
| 18 | 讨论流错误态 | `community_posts_feed.dart` → `MoeErrorState` + `MoeLoading` |
| 19 | 商业化主色/背景 | `vip_center_page`、`wallet_page`、`vip_purchase_page`、`vip_order_confirm_page`、`recharge_page`、`gacha_page`、`order_center_page` |
| 20 | 商业化加载 | VIP/钱包页 `CircularProgressIndicator` → `MoeLoading`（关键路径） |

---

## P5 待续（下一轮）

- AI 子域：`ollama_chat_page`、`chat_page` 等 `ListTile` / 硬编码色
- 游戏 / AutoGLM / `edit_profile_page` 硬编码色
- `friends_page` 抽出 `FriendsFriendCard` widget
- `MoePageScaffold` 新页面默认 adoption
- 全库 `CircularProgressIndicator` → `MoeLoading`（~70 处，低优先级）

---

## 验收路径

| 路径 | 预期 |
|------|------|
| **我的** | 二次进入瞬间出头像；无缓存仅居中 loading |
| **同好 → 会话** | 空态 CTA；失败 `MoeErrorState` |
| **社区 → 讨论** | 失败显示「暂时没能加载…」+ 重试（非 Material 按钮） |
| **VIP / 钱包** | 加载为 `MoeLoading`；主色随设置 → 外观变化 |
| **深色模式** | 五大 Tab 背景变深（非固定 `#F5F7FA`） |

### 验证命令

```bash
cd /Users/xuxinzhi/Documents/gowork/moe_social
flutter analyze \
  lib/pages/feed/home_page.dart \
  lib/pages/profile/friends_page.dart \
  lib/pages/profile/profile_page.dart \
  lib/pages/community/community_posts_feed.dart \
  lib/pages/commerce/vip_center_page.dart \
  lib/pages/commerce/wallet_page.dart \
  lib/pages/commerce/vip_purchase_page.dart \
  lib/pages/commerce/vip_order_confirm_page.dart \
  lib/pages/commerce/recharge_page.dart \
  lib/pages/commerce/gacha_page.dart \
  lib/pages/commerce/order_center_page.dart \
  lib/pages/profile/widgets/
```

---

## 复用性评估

| 资产 | 落地情况 |
|------|----------|
| `MoeTokens` / `MoeTheme` | SSOT；主 Tab + commerce 已接入 |
| `MoeEmptyState` | `deferred_route`、`conversations_page` |
| `MoeErrorState` | 主 Tab + 讨论流 + deferred |
| `MoePageScaffold` | 别名已有；P5 adoption |
| `MoeMenuCard` | 设置域；AI/聊天仍有 `ListTile` |

---

## 建议的下一轮 CE

1. **`/ce-work`** — P5：`ollama_chat_page` 色值 + `ListTile` 收敛
2. **`/ce-work`** — `friends_page` 抽出 `FriendsFriendCard`

---

## 附录

- P0–P4 验证：`flutter analyze` 上表路径 → **0 error**（2026-05-29）
- `withOpacity` 全库：**0 残留**
- `lib/pages/commerce/**` 硬编码 `0xFF7F7FD5`：**0 残留**
- `lib/pages` 深域仍有硬编码主色：**~30 文件**（AI/游戏/认证/编辑资料等）
- 未覆盖：`moe-admin/`
