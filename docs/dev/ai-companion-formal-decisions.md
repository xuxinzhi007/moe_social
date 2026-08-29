# AI 陪伴正式化决策记录（SSOT）

> **日期**：2026-07-31  
> **状态**：已确认 · 一期已落地 · 二期-A 已落地 · **互动闭环 Slice-1/2 已落地**（2026-07-31）  
> **迭代方案**：`docs/dev/ai-companion-interaction-loop.md`

> **相关**：`docs/product/product-positioning.md` · `docs/dev/ai-companion-backend-boundary.md` · `lib/constants/feature_flags.dart`

新会话接续时：**先读本文**，再改 Companion / Life / 酒馆相关代码。

---

## 1. App 整体位置

| 层级 | 结论 |
|------|------|
| P0 | Feed / 好友 / 私信（社交主路径） |
| P1 增强 | **长期虚拟陪伴**（Companion）+ **世界养成**（Life，延伸） |
| 默认隐藏 | 小游戏 / 互动故事 / 抽卡（`FeatureFlags.showGameFeatures = false`） |
| 不当主路径 | AI 酒馆大厅（多卡选角工具箱） |

一句话：社交平台里的「懂你的长期 TA」；世界是 TA 生活的舞台，不是游戏大厅。

---

## 2. 已锁定产品决策

| # | 决策 | 选型 |
|---|------|------|
| 1 | 陪伴 vs 世界 | **陪伴为主，世界为延伸** |
| 2 | 一期伙伴数量 | **单个主伙伴**；二期再谈多角色 |
| 3 | 世界入口强度 | **中等**：关系页「TA 的世界」条 + 可进入 |
| 4 | 底栏第一眼 | **关系首页**（身份、近况、主 CTA 聊天、日常流） |
| 5 | 「TA 的日常」一期 | **世界近况 + 社区动态**；二期再加聊天高光 |
| 6 | 首页陪伴入口 | **轻存在感**（底栏为稳定入口；有明确待回应时由主壳一次性提醒 Sheet 引导）；不常驻陪伴卡片 |
| 7 | 改造力度 | **收口**：改叙事与路径，不先大删酒馆代码 |
| 8 | 酒馆命运 | **退役向（A）**：不进正式导航；需要的能力迁 Companion；大厅不当多角色载体 |
| 9 | 二期多角色形态 | **暂不定（C）**：一期单伙伴；协议/数据勿写死到「永远只能一个」 |
| 10 | 二期壳层（多居民世界） | **方案 2**：关系首页仍第一眼；2D 地图只在「TA 的世界」；点地图居民照料/详情（非酒馆选卡） |
| 11 | 小世界渲染实验 | **Flame**（`useFlameLifeWorld`）；可关 Flag 回退 CustomPaint；见 `docs/dev/flame-life-world-experiment.md` |
| 12 | 身份分层 | **双层**：关系层 = 名字/头像/人设（用户自定义）；世界层 = `life_entity_id` 居民舞台。绑定不覆盖关系层形象 |
| 13 | 自定义角色一期 | **轻量**：头像图 + 名字 + 人设；不做 Live2D/角色卡大厅；多 bond 仍延后 |
| 14 | 绑定与死亡 | **绑定居民免死**（tick/dedupe 跳过）；失踪不解绑，暴露 `world_bind_status=bound_missing` + Hub 提示 |
| 15 | TA 的日常 | 世界侧 SSOT = `life_event_logs`（按 `life_entity_id`，含软删除历史）；经 `/api/companion/state.moments` 下发 |
| 16 | 完整养成（Pet Life Sim） | **Flag 独立域**（`petLifeSim`）：Flutter + Flame 小家养成，对标宠我一生能力面分期交付；**不替代**关系首页 / Feed / 私信；与 Life 多居民地图分离。SSOT：`docs/dev/pet-life-sim-roadmap.md` |

---

## 3. 技术含义（一期 / 二期）

### 3.1 正式主路径（在用）

```text
底栏 AI伙伴 → CompanionHubPage（关系首页 UI）
  → CompanionChatLauncher → /ai-chat → CompanionChatPage
  → SSE /api/companion/chat/stream
  → 世界：LifeWorldPage（延伸）
```

- 版本元数据与业务身份：`/api/companion/*`
- 页面类名 `CompanionHubPage`（文件 `companion_hub_page.dart`）；**对外文案为「AI伙伴」**

### 3.2 酒馆（退役向）

- `AgentListPage` / `ChatPage` / `/api/ai/agents` 等：**不进主导航**
- **不是**二期「多角色陪伴」的实现载体
- 代码可暂留；二期若复用人设/lore，须迁入 Companion 契约，禁止再开双栈大厅

### 3.3 多角色预留（方案 C，未实现 UI）

**一期事实**：`companion_profiles.user_id` 唯一 → 每用户一条活跃 profile（当前 API `GetProfileByUserID`）。

**二期可演进（未开工，仅约束）**：

- 产品形态届时再选：多个独立伙伴 / 主伙伴+配角
- 演进时优先：扩展 Companion 域（多 bond / profile 列表 + 当前活跃 ID），**不要**复活酒馆选卡大厅
- 一期禁止：在 Flutter 写死「全局永远只有一个 Companion」的死常量业务逻辑；展示层按「当前活跃伙伴」理解即可
- 一期不做：多伙伴切换 UI、多会话列表

---

## 4. 明确不做（当前阶段）

- 不以酒馆/游戏作为 AI Tab 主叙事
- 不在首页复制一整套 AI 面板（发动态/社区等）
- 不为多角色提前上复杂架构（Wire 多表、切换器等）
- Life 页在 `showGameFeatures=false` 时不得漏「互动故事」进游戏栈

---

## 5. 回滚与文档同步

- UI 收口可回滚到关系首页改造前的 GameHub 仪表盘布局；Flag 与酒馆退役策略保持
- 若变更上述决策：先改本文，再改 `product-positioning.md` 对应段落，最后改代码

---

## 6. 一期验收清单

- [x] 底栏 AI伙伴 = 关系首页 + 聊天主按钮 + 世界条 + 日常流（`companion_hub_page` / `companion_hub_viewmodel`）
- [x] 首页仅轻存在感，无重复发动态/社区 Chip；不常驻 Companion 卡片，有待回应时由主壳一次性提醒（`home_page` / `main_shell`）
- [x] 快捷操作无第二套「AI 伙伴」入口（`quick_actions_grid`）
- [x] Life 无互动故事入口（Flag 关时）（`life_world_page`）
- [x] 酒馆无主导航入口（仅经已隐藏的 GamePlay 可达；`showGameFeatures=false`）
- [x] 决策落档 + 多角色方案 C 预留注释（本文 · `FeatureFlags.companionSingleActiveBondPhase1`）

### 二期进度（顺序 D = A → 可选轻量 C → B；并行互动闭环）

- [x] **A. 日常流**：并入聊天高光（`chat`）+ 记忆碎片（`memory`）；聊天条可点进会话
- [x] **C. 工程收口（轻量）**：`GameHubPage` → `CompanionHubPage`；GamePlay→酒馆入口受 `showGameFeatures` 门控；酒馆页加退役注释
- [x] **壳层方案 2**：`LifeWorldPage` = 2D 地图优先；Flame 实验见决策 11
- [x] **互动闭环 Slice-1**：照料语气 + moments + 日常深链 + 世界「去聊天」+ Hub 返程刷新
- [x] **Slice-2**：Companion WS + 「TA 想你了」角标 / Hub 状态提示 + 首页按需提醒 Sheet
- [x] **轻量自定义 + 双层身份**：`avatar_url`；绑定不覆盖人设；Hub 可上传头像
- [x] **Slice-3**：聊天/照料亲密度微增；社区 bot 自动创建；删除死代码 `companion_context`
- [x] **Slice-4**：记忆专页 `/ai-memories`；日常流 memory 深链 + 进聊天 CTA
- [x] **Slice-5**：角色卡轻量导入（ST JSON/PNG → 关系层人设；不复活酒馆）
- [x] **Slice-6**：记忆删除/置顶 + Companion 轻量语音（STT/TTS；仍不做 Live2D）
- [x] **Slice-6.1**：记忆编辑正文 + Hub 导入引导 + 置顶注入标注
- [ ] **B. 多角色（Companion 多 bond）**：未开工；勿把 Life 地图点选误当成多会话已完成

仍勿误开工：Companion 多 profile 表结构、酒馆大厅复活、Live2D 大厅。
