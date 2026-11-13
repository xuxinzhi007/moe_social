# 设计稿 · 当前萌系心情社交壳

这是现在 App 上用户能看见的壳：五栏底栏、三条冻结主路径、Airy Moe 色板。视觉实现以 `lib/theme/moe_tokens.dart` 为准。产品边界以 [product-positioning.md](../product/product-positioning.md) 为准。

打开同目录 [design.html](./design.html) 看色板和手机框。要改页面时读 `moe-flutter` 与 `moe-ui-design`，不要在页面里另写一套颜色。

## 给谁用、做什么、什么语气

| | |
|--|--|
| Audience | 记录日常、看动态、和好友说话，并有一个长期 AI 伙伴的用户 |
| Job | 发帖、浏览互动、建立关系；陪伴和养成是旁路 |
| Tone | 静奢雾蓝鸢尾：低饱和、云母底、白卡片、细描边。代码注释写明已弃用旧塑料紫 `#7F7FD5` |

## 底栏（已证实）

`lib/app/main_shell.dart` 的 `MainPage` 用 `IndexedStack` + `MoeBottomBar`，五个目的地：

| 序 | 标签 | 页面 |
|----|------|------|
| 0 | 首页 | `HomePage` |
| 1 | 好友 | `MessageCenterPage`（deferred） |
| 2 | AI伙伴 | `CompanionHubPage`（deferred） |
| 3 | 社区 | `CommunityHomePage`（deferred） |
| 4 | 我的 | `ProfilePage`（deferred） |

好友角标来自 `NotificationProvider.directMessageUnreadCount`。AI 伙伴角标在当前就停在该 Tab 时隐藏，避免和 Hub 横幅重复。

**存在冲突：** `moe-flutter` 写「主 Tab ≤4」。当前壳是 5 个。以 `MainPage` 为准；技能条文是收口目标，代码还没收成四栏。

## 三条冻结主路径（已证实，定位文档）

1. 记录心情：`CreatePostPage`，单卡片表单（文案、附件、心情、话题）。
2. 浏览互动：`HomePage` → 动态详情 / 评论。
3. 建立关系：消息中心 → 私信 / 好友。

主路径体验条（`moe-flutter`）：Feed 有骨架和可重试错误；发帖失败可见且草稿可恢复；评论乐观插入、失败回滚；私信未读可见、WebSocket 断线可见。

## 色板（已证实，`MoeTokens`）

| Token | 色值 | 用途 |
|-------|------|------|
| `primary` | `#5E6AD2` | 品牌鸢尾 |
| `secondary` | `#7C8CF8` | 雾蓝 |
| `accent` | `#64D2C8` | 青瓷点缀 |
| `pageBackground` / `surface0` | `#F6F7FB` | 页面底，不用纯白铺满 |
| `cardBackground` / `surface1` | `#FFFFFF` | 卡片 |
| `inkDark` / `titleText` | `#181A20` | 标题 |
| `bodyText` | `#2E323D` | 正文 |
| `surfaceBorder` | `#E6E8F0` | 细描边 |
| `success` / `danger` / `warning` | `#16A34A` / `#E11D48` / `#D97706` | 只做语义 |

主 CTA 渐变 `#5E6AD2 → #6E7AE2`（`gradientPrimary`）。圆角：小控件 8/12，卡片 20，大面板 24，胶囊 9999。间距 4px 网格，页面水平留白通常 16。

**存在冲突：** `docs/DESIGN_SYSTEM.md` 仍写 `primary #7F7FD5`、`surface0 #F5F7FA`。该文件自己也说与 `MoeTokens` 冲突时以代码为准。做新页面用本表，不要抄 DESIGN_SYSTEM 的旧色值。`.cursor/rules/frontend-ai-spec.mdc` 里的主渐变 `#7F7FD5 → #86A8E7` 同样过时。

## 开关（已证实，`lib/constants/feature_flags.dart`）

| 开关 | 当前值 | 含义 |
|------|--------|------|
| `arenaGamePrototype` | `false` | 星辉远征默认不可见，不做首页卖点 |
| `showExperimentalFeatures` | `true` | 内测总开关；商店包发布前要关 |
| `companionVoicePresence` | `true` | 陪伴语音输入和朗读，不做 Live2D |
| `glassNavigation` | `true` | 导航毛玻璃 |
| `chatVoiceMessage` | `true` | 语音消息 |

实验总开关打开时，回复参谋、AutoGLM、直播礼物 PK、联机实验会跟着露出。普通用户路径仍是社交壳。

## 页面骨架

新页面用 `MoePageScaffold` / `AdaptivePageScaffold`，按压用 `MoePressable`，入场用 `MoeReveal`。加载、空、错误三态复用现有组件，错误必须能重试。同一能力只留一个主入口，底栏已有的不要在首页再做一张入口卡。
