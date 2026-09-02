# 全栈审查报告（产品方向 / 代码 / UI）· 2026-09-02

> **状态**：一次性快照审查。结论基于当日 `feat/kratos-hybrid-migration` 分支 HEAD（`1de7b4af`）；
> 行动项完成后本文**无需持续维护**，产品边界 SSOT 仍以 [../product/product-positioning.md](../product/product-positioning.md)、[aurora-arena-ssot.md](./aurora-arena-ssot.md) 等为准。
>
> **验证方式**：git 历史梳理（近 10 个提交）+ 关键文件精读 + `flutter pub get` 后 `flutter analyze`（0 error / 37 info）+ 本轮新增 Widget 测试 9/9 通过（about_module / message_bubble / post_card_media）。

---

## 一、最近提交改动整理（2026-08-23 ~ 08-30）

| 提交 | 日期 | 主题 | 规模 |
|------|------|------|------|
| `1de7b4af` | 08-30 | Android 异地联机实验（VPN 中继 + WS relay）+ 版本号/话题标签/清理 | +2420/-511 |
| `7db9884b` | 08-30 | **UI 视觉升级迭代 1**：首页收口、Provider 管理化、气泡/卡片升级 | +2241/-968 |
| `3074fbe6` | 08-29 | 统一主题样式（Companion Hub / 私聊 / 底栏 / 卡片） | +761/-500 |
| `3c014c8e` | 08-28 | Edge TTS 语音朗读 + 聊天页重构 | +631/-367 |
| `0ff0ab1b` | 08-28 | **星辉远征上线，替换旧宠物养成模块** | — |
| `19afb151` / `5c1b438a` | 08-27 | Arena 横屏卡牌 PvE 原型 | — |
| `2b31e3c2` / `544f2dd9` | 08-24~25 | 聊天主题皮肤 + 语音消息 + 18 项 review 修复 | — |
| `8801da8f` | 08-23 | 首页主线收束与设计系统统一 | — |

**两周实际主线**：UI 收束（方向好）→ 但同时叠加 Arena 游戏上线、异地联机实验、直播礼物 PK 三条游戏化支线。

---

## 二、产品方向评估：定位文档与代码现实已脱节

### 2.1 核心矛盾

`docs/product/product-positioning.md`（生效 2026-06-29）自称「萌系心情社交 App」，明确写着：

> 「不以游戏、抽卡作为产品卖点」 / 数字生命暂缓方向含「**多人联机**」

但 8 月的代码事实：

| 定位文档说 | 代码现实 |
|-----------|---------|
| 不做游戏卖点 | `FeatureFlags.arenaGamePrototype = true`，Arena 全量上线（约 7000 行），Companion Hub 有显著入口 |
| 暂缓多人联机 | `FeatureFlags.showGameNetworkLab = true`，VPN + WS 中继全套实现 |
| Pet Life Sim 是 Flag 域（SSOT 指向 pet-life-sim-roadmap.md） | `lib/pages/pet`、`lib/game/pet`、`lib/game/farm` **已全部删除**，`aurora-arena-ssot.md` 宣告「星辉是唯一游戏壳」 |
| 数字生命是 P1 增强 | `showLifeEngine = false` 已关闭，但 `useFlameLifeWorld = true` 仍开着，Flame 代码/路由/十余篇文档残留 |

**结论**：方向摇摆过快（一个月内 宠物 → Arena → 异地联机农场），每次均为「替换式」大改。最大风险不是某个功能做错，而是**同时维持三个游戏的半成品**（Arena、直播 PK、农场联机实验）+ 大量半退役模块（gacha、小游戏、Life），叠加「社交为主」叙事，精力被切成四五份。

**建议**：先做一次诚实的定位收口——要么承认「AI 陪伴 + 轻游戏化」是主线并更新文档，要么按现有文档收缩游戏支线。

### 2.2 功能闭环断裂点（面向用户维度）

- **无意义网络请求**：`lib/pages/feed/home_feed_viewmodel.dart` 中 Companion snapshot 仍在请求/刷新，但首页已移除展示（ui-upgrade-iteration §7 已承认的债务，未闭环）。
- **实验页穿透到普通用户**：异地联机入口挂在「设置 → 高级选项」，与 AutoGLM 同级；flag 为 true 时普通用户可达，且 VPN 权限系统弹窗对普通用户是惊吓体验。
- **文档债务**：`docs/dev/` 下 12+ 篇 pet/farm 文档残留；positioning 仍引用已删除模块作为 SSOT，会严重误导新协作者。

---

## 三、代码审查发现（功能闭环视角）

### P0 — 必须处理

1. **[安全] JWT 放入 URL 查询参数**
   `android/.../GameNetworkVpnService.kt` 的 `buildRelayUrl()` 把 token 拼进 `?token=`。
   后端 `ws_relay.go` 的 `extractToken` 优先读 Authorization 头，原生端也已带该头，query 里的 token 纯属多余，却会进访问日志/代理日志。**一行删除即可**。

2. **[安全] 房间号可枚举抢占**
   `backend/internal/biz/game_network/ws_relay.go` 只校验 JWT 有效，不校验房间归属；而房间号由 `farm-时间戳base36后6位` 生成（熵极低）。任意登录用户可猜房间号，以 guest 身份抢占房间中继对方流量。实验期可控；**发布前必须随机化房间号（如 4 字节随机 hex）或关闭 flag**（代码注释已承诺「发布前关闭」，应落实为发布清单项）。

3. **[供应链] `edge_tts` 包已 discontinued**（`pub get` 明确警告）。TTS 是 Companion 核心体验，建议尽快评估替代（`flutter_tts` 本地引擎或自建 Azure 代理）或 pin 版本 + 审计。

### P1 — 近期处理

4. **提交粒度失控**：`1de7b4af` 单 commit 混入 8 项不相干改动（VPN 实验 + 版本号 + 话题标签 + Hero 清理 + 云相册 + gitignore）。实验功能与收口清理应分离，否则无法独立回滚。
5. **[ws_relay.go] `CheckOrigin: return true`**：接受任意 Origin 的 WS 升级，应校验同源（有 Bearer 保护，降为中风险）。
6. **VPN 前台通知使用系统警告图标**（`stat_sys_warning`）：Google Play 对 VPN 类应用有合规审查要求，需替换为应用自有图标。
7. **`lib/pages/arena/arena_page.dart` 达 5122 行**：单文件承载大厅/小家/编队/爬塔/召唤/战斗全部 UI，125 处 MoeTokens 与 68 处硬编码 `Color(0x...)` 混用。
8. **37 条 info 级 lint**：`avoid_print`（autoglm/gacha 页）、`use_build_context_synchronously` 等，建议加入 CI 阈值防止增长。

### 值得肯定的工程质量

- 新增测试意识强：about_module（含窄屏适配断言）、message_bubble（错误恢复）、post_card 媒体密度均有 Widget 测试且全过。
- 原生 VPN 代码质量高：原子状态位、指数退避重连、前台通知、IO 写锁、stale socket 防护。
- relay 实现规范：房间满员/角色冲突校验、ping/pong 超时、写锁、帧大小限制。
- 生命周期管理普遍正确（dispose 链完整、mounted 检查到位）。

---

## 四、前端 UI 审查

### 4.1 过度设计的信号（正在收敛，方向正确）

- **大 Hero 渐变头部正在被清理**：`1de7b4af` 删除了 user_qr_code_page 119 行、character_card_plaza 41 行的装饰性 Hero 块——本轮最有价值的「减法」。
- **about_module 742 行承载 4 个菜单项**：反馈面板做了类别选择、字数统计、窄屏自适应——对低频入口功能密度偏高，但测试齐全，属可接受范围。
- **message_bubble 气泡装饰嵌套三元达 5 层**（`lib/widgets/ai/message_bubble.dart` 约 L393-L447），圆角/边框/阴影组合爆炸，维护成本高，建议拆分出样式解析函数。
- **Hallmark 设计 Skill 标记注释覆盖不一致**：仅 5 个文件带 `// Hallmark · layout…` 头注（home_page、message_bubble、about_module、companion_attention_sheet、companion_chat_page），且 `Self-critique: …` 评分行属过程性产物。建议统一决策：要么所有新页面都带 Hallmark 标记，要么移除评分行只留布局说明。

### 4.2 设计太简单 / 缺失的场景

- **无深色模式**：`lib/theme/moe_tokens.dart` 全为浅色静态常量；`MoeTheme` extension 有 light/dark 工厂但 app 未接入 `darkTheme`。目标用户（年轻二次元向）对深色模式期待高，属**最大体验缺口**。
- **GameNetworkLabPage 完全没走 Moe UI**：`SegmentedButton` / `FilledButton` / 默认 `TextField` / 原生 `SnackBar`，与全站视觉割裂。要么对齐，要么在文件头声明「实验页豁免设计系统」。
- **ui-upgrade-iteration UI-1C 未完成项**：320px 窄屏冒烟、平板宽度约束、reduced motion 全链路、键盘顶起场景——文档已标记 TODO，尚未闭环。

### 4.3 样式不统一清单

| 问题 | 位置 | 严重度 |
|------|------|--------|
| 三套色彩体系混用：MoeTokens（浅萌）+ AiBrandTokens（AI 域）+ _ArenaColors（游戏深色） | 全局 | 低（分层有合理性） |
| Arena 页 68 处硬编码色游离于 `_ArenaColors` 7 常量之外 | `arena_page.dart` | 中 |
| settings 域 25+ 处 `Colors.white/grey/blue` 直用 | `settings_page.dart` 等 | 中 |
| `CompanionArenaGameEntry` 卡面硬编码 `Colors.white` | `companion_hub_page.dart` | 低（接入深色模式即破） |
| 代码块气泡硬编码 `0xFF1E1E1E`、post_card 用 `Colors.grey.shade200` | `message_bubble.dart` / `post_card.dart` | 低 |

### 4.4 做得好的场景（保持）

- 底栏窄屏分级（330/360px 双阈值 + FittedBox 防溢出）。
- 媒体密度 Token 化（feed 200px / detail 320px 上限，测试锁定）。
- `moeReduceMotion` 无障碍机制贯穿 motion 组件。
- 新组件带 `Semantics` 标签（Arena 入口、底栏）。
- Provider 页从「说明页」改「管理页」+ 统一空态，信息架构正确。

---

## 五、行动建议（按优先级）

### P0（本周）

1. 删除 relay URL 中的 `token` 查询参数（一行修复）。
2. 房间号加随机熵（4 字节随机 hex）+ 可选归属校验；把「发布前关闭 `showGameNetworkLab`」写进发布清单。
3. 重写 `product-positioning.md`：删 Pet Life Sim 章节，如实写入 Arena / 直播 PK 定位；归档 pet 系列旧文档。

### P1（两周内）

4. GameNetworkLabPage 对齐 Moe UI 或标注豁免；统一 Hallmark 注释策略。
5. 移除 `HomeFeedViewModel` 的 Companion snapshot 残留请求。
6. 评估 `edge_tts` 替代方案。
7. 提交纪律：一个 commit 一个主题，实验功能与收口清理分离。

### P2（规划中）

8. 深色模式：基于现有 `MoeTheme` dark 工厂补全 token 映射，优先三条冻结主路径（记录心情 / 浏览互动 / 建立关系）。
9. `arena_page.dart` 按「大厅 / 小家 / 战斗」拆分；硬编码色收编进 `_ArenaColors`。
10. 完成 ui-upgrade-iteration UI-1C 的窄屏 / 平板 / 无障碍冒烟清单。
11. 对 gacha / 小游戏 / Life 三个半退役域做一次「删除或归档」的最终决策。

---

## 附：验证记录（2026-09-02）

| 项 | 结果 |
|----|------|
| `flutter pub get` | 成功；提示 `edge_tts` discontinued、139 包可升级 |
| `flutter analyze` | 0 error / 37 info（info 明细见 §三-P1 第 8 条） |
| `flutter test`（本轮新增 3 个文件） | 9/9 通过 |
| 测试文件 | `test/pages/settings/about_module_test.dart`、`test/widgets/ai/message_bubble_test.dart`、`test/widgets/post_card_media_test.dart` |

**总体判断**：UI 治理这条线（迭代文档 + Token 体系 + 测试）执行质量高、方向正确；真正的风险在产品侧——定位文档与代码现实的漂移、以及三条游戏支线同时铺开导致的闭环断层。建议「先收口、再扩张」。
