---
name: moe-flutter
description: >-
  Unified Moe Social Flutter project skill: product boundaries, production
  architecture (thin pages, ViewModels, domain services, FeatureFlags), MoeTokens
  UI craft, success-app P0 loops, and strict audit/review. Use for any lib/
  Flutter work, 正式产品/收口, UI design/redesign, hallmark, or when the user asks
  to audit/review Flutter code.
---

# Moe Flutter（统一项目 Skill）

单一入口。覆盖：**产品边界 · 正式架构 · 成功 App 主回路 · UI 手感 · 严格审核**。

| 模式 | 用户说法 / 触发 | 行为 |
|------|-----------------|------|
| **implement**（默认） | 改页面、修 BUG、加功能 | 按架构条 + 主回路体验条实现 |
| **design** | 新页面视觉、Hallmark、redesign | Token + 反 slop；可 redesign |
| **audit** | audit / 审核 / review Flutter | **只评不改**，输出打分清单 |
| **study** | 给了截图/URL 学风格 | 抽 DNA，再问是否套用 |

细节：
- 架构补改删 / 分层 → [product-reference.md](product-reference.md)
- 好坏对照 → [examples.md](examples.md)
- 视觉 gates 全文 → [references/slop-test.md](references/slop-test.md)
- 布局模式 → [references/layout-patterns.md](references/layout-patterns.md)
- 反模式 → [references/anti-patterns.md](references/anti-patterns.md)

改动幅度：始终叠加 [implementation-guardrails](../implementation-guardrails/SKILL.md)。

---

## 0. 产品边界（永远生效）

- App：**萌系心情社交**。主路径 = 发帖 / Feed / 私信(+好友)。
- AI / Companion / Life = 增强陪伴，不是工具箱或游戏大厅。
- Game / gacha / AutoGLM：默认隐藏，走 `FeatureFlags`；无明确要求不要加主导航。
- 主 Tab ≤4；实验无入口、无假开放路由（Flag=false 时）。
- SSOT：`docs/product/product-positioning.md` + `lib/constants/feature_flags.dart`。
- 目录：`lib/pages/<domain>/` · `widgets/` · `services/` · `providers/` · `app/app_routes.dart`（重页 deferred）。

---

## 0.5 成功 App 主回路（P0 体验条 · 对标小红书/IG/微信/Discord）

实现与审核时，P0 必须满足下列体验（缺一记 Fail）。**不要**为此全仓重构；只打主路径。

| 回路 | 必须有 |
|------|--------|
| **Feed** | 首屏骨架；空/错三态；失败 **可重试**（`MoeErrorState.onRetry`） |
| **发帖** | 一屏完成主流程；上传/发布失败用 `MoeErrorCopy`；**本地草稿可恢复**（非仅 Pop 确认） |
| **评论** | 列表三态；发送 **乐观插入**；失败 **回滚 + 可见提示** |
| **私信** | 未读角标；WS **自动重连**；断线/发送失败 **用户可见**；禁止静默吞发送错误 |
| **登录** | 业务错保留短文案；网络/异常走 `MoeErrorCopy`；**禁止密钥进仓库** |
| **砍面** | Tab≤4；Flag=false 无入口、路由占位「已下线」 |
| **质量** | PR CI：`flutter analyze` + `flutter test`；未捕获错误进可观测缓冲（`CrashReportBuffer`） |

**正式对照：** 赢在主回路可靠 + 环境正确 + 失败可见；不要用「每个次要页抽 VM / 全仓消魔法色」当收口标准。

---

## 0.6 单一入口（禁止重复冗余展示）

同一用户能力在 App 里**只保留一条主路径入口**。多处放同一入口意义不大，徒增噪音与维护成本。

### 入口优先级（高 → 低）

1. **底栏 Tab**（`main_shell`：首页 / 好友 / AI伙伴 / 我的）
2. **该 Tab 内的主 UI**（列表、FAB、主 CTA）
3. **上下文入口**（仅当前流程需要时出现，如发帖里的「云端图库」）
4. **「我的」菜单 / 设置** — 只放**底栏没有、且需低频找得到**的能力（社区、云图库、设置…）

### 实现 / 改导航前必检

```text
- [ ] 这条能力底栏或主路径是否已有入口？有 → 不要再加菜单/Chip/快捷卡片
- [ ] 同一页面内是否已有专区/按钮？有 → 工具栏勿再放同名入口
- [ ] 装饰文案是否做成了「假按钮」Chip？是 → 删掉或改成纯文案
- [ ] Flag=false 的能力是否仍有可见入口？有 → 一并去掉
```

### 已确认案例（勿回潮）

| 冗余 | 保留 | 去掉 |
|------|------|------|
| 底栏「好友」 vs 「我的→同好与联系人」 | 底栏「好友」 | 我的菜单项 |
| 发帖工具栏「#话题」 vs 「话题标签」专区 | 话题标签专区 | 工具栏 Chip |
| 云图空态装饰 Chip（看起来可点） | 唯一「上传」CTA | 假按钮 Chip |

**例外（允许）：** 深链/路由仍可直达；通知点击进会话；空态 CTA 引导去已有主入口（跳转，不复制一整套 UI）。

Audit 触及导航/菜单时：重复入口记 **R1 Fail**（见下节）。

---

## 1. 正式产品硬约束（Non-negotiables）

1. **主路径优先** — P0 打磨到位；P1 弱入口；实验必须 Flag。
2. **薄页面** — Page = 编排/导航/动效；状态与 IO 在 `ChangeNotifier` ViewModel / Provider。禁止新造 1k+ 行 god-page。
3. **禁止页面/组件 HTTP** — 只调域服务。禁止 `ApiService` / 裸 `ApiClient` / `package:http` 出现在 `pages/`、`widgets/`（AutoGLM 实验页除外且须 Flag）。
4. **MoeTokens** — 新 UI 色/间距/圆角/阴影/动效一律 token。
5. **三态** — `MoeLoading` / `MoeEmptyState` / `MoeErrorState`（+ `MoeErrorCopy`）。
6. **Flag = UI** — flag 为 false 时无入口、无 AppBar 动作、无「假开放」路由。
7. **单一入口** — 见 §0.6；底栏/主路径已有的能力不要在「我的」或同页工具栏再挂一份。
8. **不整仓换栈** — 保持 Provider + `app_routes`。
9. **密钥与环境** — 第三方 API key 不得硬编码进仓；现阶段用 `AppConfig` 安全存储 / 设置页配置。基址用 `lib/utils/config.dart` 的 `isProduction` 切换，**上线前再切生产**（勿提前强制 `kReleaseMode`）。

### 实现检查清单

```text
- [ ] 路径级别：P0 | P1 | experimental(+flag)
- [ ] 已对照 §0.5 主回路 + §0.6 单一入口（若触及导航/菜单/快捷入口）
- [ ] 已搜现有 service / widget / VM
- [ ] 新逻辑进 ViewModel（或扩展现有）
- [ ] 无 page/widget HTTP 泄漏；无新密钥进仓
- [ ] Token + 三态；失败可见（禁 silent catch 主路径）
- [ ] flutter analyze --no-fatal-infos（touched，无 error）
```

### 栈锁定

| 项 | 用 | 勿擅自换 |
|----|----|----------|
| 状态 | Provider / ChangeNotifier VM | 全仓 Riverpod/Bloc |
| 路由 | `app_routes` + `DeferredRoute` | 并行路由框架 |
| 主题 | `MoeTokens` + moe_* | 第二套设计系统 |
| 网络 | Domain `*Service` | 页面直连 |

参考 VM：`home_feed_viewmodel` · `conversations_viewmodel` · `direct_chat_viewmodel` · `create_post_viewmodel` · `comments_viewmodel` · `companion_hub_viewmodel` · `game_play_viewmodel`。

**反过度设计：** 不为好看抽 VM；仅列表/分页/发送等可测状态才抽。Skill 只补踩坑。默认头像用空串 + 本地占位，禁 picsum。

---

## 2. UI 手感（design 模式）

1. 读 `MoeTokens`；同域先扫 2–3 个现有页。
2. 明确 Audience / Job / Tone（kawaii-soft · playful · clean-modern · editorial · utilitarian）。
3. 先选布局模式（见 [references/layout-patterns.md](references/layout-patterns.md)），同会话连续页勿同骨架。
4. 禁默认 Material 裸 `AppBar`/`Card`/`ListTile`（必须 Moe 定制）。
5. **多机适配 / 防溢出（必做）** — 见下方 §2.1。
6. 动效优先 `MoeReveal` / `MoeStaggerReveal` / `MoePressable`（见 `lib/widgets/motion/`）。
7. **先搜仓库再写** — 空态用 `MoeEmptyState`，错态用 `MoeErrorState`，加载用 `MoeLoading`/`PostSkeleton`；禁止再造一套空态面板。
8. **可感知微交互** — 列表前几项 stagger；按压用 `MoePressable`；草稿恢复等后台能力要有 Toast/轻提示。
9. **能复用就复用** — 已有包与 `lib/widgets/layout/*` 优先；不为视觉新引大型动画库，除非用户点名。
10. 发出前跑视觉 slop gates（含 **G21 硬编码宽 / G22 overflow**）。

### 2.1 多机适配与 Overflow（手机小屏 ↔ 大屏 / 平板）

黄黑条 `A RenderFlex overflowed by N pixels` = 布局约束不够，不是「调个 fontScale 全局缩放」能根治。优先约束流，不要 `Transform.scale` 整页糊弄。

| 场景 | 做法（优先用仓库已有） |
|------|------------------------|
| 新列表/表单页骨架 | `AdaptivePageScaffold` / `MoePageScaffold`（自带 `maxContentWidth`≈600，平板居中） |
| `Row` 里长文案 / 多按钮 | 文案 `Expanded`/`Flexible` + `maxLines` + `TextOverflow.ellipsis`；按钮区 `Wrap` 或缩小 `FittedBox` |
| `Column` 固定高度里塞列表 | 列表外包 `Expanded`，或整页改 `CustomScrollView`/`ListView`，禁止「不可滚动 Column + 大块子树」 |
| 顶栏过厚、只有底部能滑 | 用 `NestedScrollView`：顶卡可滚走、筛选 Tab 可吸顶；子 Tab 用 `CustomScrollView` 一体滚动（兴趣社区已采用） |
| 小屏 AppBar / Chip 行 | `Wrap`、横向 `SingleChildScrollView`，或 `LayoutBuilder` 窄屏改两行 |
| 数字/标题过大 | 局部 `FittedBox(fit: BoxFit.scaleDown)`（钱包等已有先例） |
| 键盘顶起 | `Scaffold.resizeToAvoidBottomInset: true` + 表单可滚动 |
| 安全区 | 底栏/刘海用 `SafeArea`；模板见 `AdaptivePageScaffold` |
| 空态过长 / 假按钮 Chip | 空态外包 `SingleChildScrollView`；**同一能力只留一个入口**；装饰文案不要做成可点按钮样式 |

**禁止：** 给 `Row`/`Column` 子项写死大 `width: 320` 却不给弹性兄弟；在无界高度（再套一层纵向 `ListView`）里再放 `Expanded`；工具栏 Chip 与下方专区重复同一操作（如发帖「#话题」+「话题标签」双入口）；**底栏已有的主入口不要再在「我的」菜单里重复**（如「好友」Tab vs「同好与联系人」）。

**调试：** Debug 开 overflow 指示；用 iPhone SE / 窄安卓 + 平板两档看同一页。修的时候只改当前溢出链，不整仓「响应式重构」。

Audit 触及 UI 时：G21/G22 Fail 要列出来。

**redesign**：只换视觉/布局；保留路由、Provider、业务与 API。  
**study**：抽 DNA → 问是否套用 → 映射到 MoeTokens。  
**历史债**：神页/魔法色不主动紧致收口；只改碰到的文件。

---

## 3. 严格审核（audit 模式 · 只评不改）

用户说 `audit` / `审核` / `review`（Flutter）或 `moe-flutter audit <path>` 时：

1. 读目标文件（或 P0 目录抽样）。
2. 按 **Architecture (A1–A8)** + **Loop (L1–L7)** + **Redundancy (R1)** + **Ship (S1–S3)** + **Visual (G)** 打分。
3. 输出报告；**默认不改代码**（除非用户说「按审核修」）。

### 报告格式

```text
**Moe Flutter Audit · <target>**

Architecture: <pass>/<8>
Loop: <pass>/<applicable L>
Redundancy: <pass>/1   (触及导航/菜单/快捷入口时)
Ship: <pass>/<3>
Visual: <pass>/<N>

Fails (severity by severity):
1. **R1 / L# / A# / S# / G#** — <问题> @ <位置>
2. ...

Top fixes:
- <最多 5 条可执行建议>
```

### Architecture gates（A1–A8）

| ID | Fail if |
|----|---------|
| A1 | `pages/` 或 `widgets/` 出现 `ApiService.` / 裸 `ApiClient.` / `package:http` 业务请求 |
| A2 | 主路径列表/会话状态只靠巨型 `setState`，无 VM/Provider |
| A3 | 有加载/空/错场景却没用 moe 三态组件（主路径） |
| A4 | 新 UI 大量魔法色/圆角，未走 MoeTokens |
| A5 | `FeatureFlags.x == false` 但仍有可见入口 |
| A6 | 实验面进了主导航 / 新 Tab（无产品授权） |
| A7 | 异步后无 `mounted` / VM `_disposed` 仍 `notify`（明显风险） |
| A8 | 主路径失败被 `catch (_) {}` 吞掉且无用户提示 |

### Loop gates（成功 App 主回路 · 触及即评）

| ID | Fail if |
|----|---------|
| L1 | Feed 首错无可重试 / 无骨架 |
| L2 | 发帖无本地草稿恢复；或上传失败只打 debugPrint |
| L3 | 评论发送非乐观且失败无回滚提示 |
| L4 | 私信发送失败不可见；或断线无重连/无提示 |
| L5 | 登录网络错未走 `MoeErrorCopy` |
| L6 | Flag=false 路由仍可进入真功能页 |
| L7 | 密钥硬编码进仓 |

### Redundancy gates（单一入口 · 触及导航/菜单即评）

| ID | Fail if |
|----|---------|
| R1 | 同一能力出现 ≥2 个并列可见入口，且低优先级入口无上下文必要（违反 §0.6） |

### Ship gates（正式上线 · 单独列）

| ID | Fail if |
|----|---------|
| S1 | 上线包仍指向开发机且无切换说明（`isProduction` / flavor 未准备）；**开发期**可暂用本地，不记 Fail |
| S2 | 第三方 API key / 密钥明文进仓库或页面常量（设置页 + 安全存储除外） |
| S3 | 无 PR `flutter analyze` + `flutter test` 质量门禁 |

### Visual gates

完整列表：`references/slop-test.md`（G1–G17 + G21–G22）。Audit 时对**本次改动的 UI**或用户指定文件执行；全文件历史债可标 `debt` 不挡分，但新引入的 fail 必须列出。

---

## 4. 完成定义

- [ ] 符合产品边界与 Flag
- [ ] 触及 P0 时符合 §0.5 / Loop gates
- [ ] 触及导航/菜单时符合 §0.6 / R1（无重复入口）
- [ ] 无新的分层/HTTP/密钥违规
- [ ] Token + 三态（触及 UI 时）
- [ ] 状态在 VM/Provider
- [ ] `flutter analyze --no-fatal-infos` 无 error
- [ ] 若用户要了 audit：已出报告

## 不做

- 后端 proto / Kratos（Go skills）
- 管理台 `moe-admin/`（另一套规范）
- 未要求的整仓重构或换状态管理框架
- 未点名接入完整 Crashlytics/Sentry（默认用内存 `CrashReportBuffer`；要 SDK 再加）
