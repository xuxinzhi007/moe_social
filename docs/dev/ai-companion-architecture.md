# AI Companion 当前架构（合并版）

> **状态**：当前架构 SSOT（2026-10 合并）
> **决策 SSOT**：`docs/dev/ai-companion-formal-decisions.md`（改边界先改它，再改本文，最后改代码）
> **代码事实**：以 `lib/` + `backend/` 为准；API 契约 SSOT = `backend/api/companion/v1/companion.proto`
> **Flame 舞台**：`.cursor/skills/flame-life-world/SKILL.md`

本文由原 5 篇文档合并而成：`ai-companion-product-plan.md`、`ai-companion-app-integration-plan.md`、
`ai-companion-interaction-loop.md`、`ai-companion-roadmap.md`、`ai-companion-backend-boundary.md`。
已废弃内容直接删除；已落地与未落地内容分别标注；矛盾处以代码现状为准。

---

## 1. 定位与边界

一句话：社交平台里的「懂你的长期 TA」；世界是 TA 生活的舞台，Feed / 好友 / 私信仍是社交主路径。
Companion 是贯穿各业务域的**关系层**，不是孤立聊天产品，也不是替代社交主线的 AI 大厅。

| 是 | 不是 |
|----|------|
| 单活跃伙伴闭环 | 多 bond UI（决策 B，未开工） |
| 关系首页第一眼（底栏「AI伙伴」） | 酒馆选卡大厅（退役向，不进主导航） |
| 世界 = 延伸舞台（现载体：Arena 营地页） | 地图点选 = 多会话 / 多伙伴 |
| 后端决定记忆 / 关系 / 主动规则 | Flutter 自行拼接 Prompt、写记忆、改亲密度 |

演进原则：增量升级，不回退重写；新增 API / 字段保持向后兼容；每切片可独立运行、可回滚、有验收。

---

## 2. App 分层与职责

```text
App Shell
├── 社交层：Feed / 好友 / 私信 / 社区
├── 关系层：Companion Profile / Relationship / Memory / Consent
├── 智能层：Context Orchestrator / LLM / Tool / Safety
├── 存在层：Presence / Proactive Event / Notification / Voice
└── 世界层：Life Entity / World State / Scene（Arena 营地页承载）
```

| 层 | 负责 | 不负责 |
|---|---|---|
| 社交层 | 帖子、评论、好友、私信 | 直接拼 Companion Prompt |
| 关系层 | TA 身份、亲密度、关系事件、记忆生命周期 | 直接调 LLM Provider |
| 智能层 | 上下文编排、模型调用、内容安全 | 决定 UI 与导航 |
| 存在层 | 主动问候、WS、通知、语音状态 | 保存未经确认的长期事实 |
| 世界层 | Life 居民、状态、场景渲染 | 作为多角色聊天列表 |

---

## 3. 后端边界（数据归属与分层）

- 请求身份只由 HTTP JWT context 提供；客户端请求体中的 `user_id` **不参与**资源归属判断。
- Companion REST、SSE、WebSocket 均按 actor user ID 隔离 Profile、记忆、聊天和推送。
- `companion_profiles.life_entity_id` 是伙伴与 Life Entity 绑定的**唯一事实来源**；
  首次访问由后端按实体 ID 稳定选择默认伙伴，切换由后端校验并持久化。
- 对象创建集中在 `internal/platform/moewiring`（不引入 Google Wire，避免与手写 wiring 双轨）。
- 应用 service 仅依赖 biz Engine/Usecase；data store 实现 biz 定义的消费侧接口。
- Flutter 只解析契约、展示状态、提交绑定，不决定数据归属；Provider 密钥不上传到 Companion。

依赖方向：

```text
protohttp -> service -> biz <- data
                         ^
                      wiring
```

多伙伴（未实现）：一期 `companion_profiles.user_id` 唯一对应一条 profile；二期若扩展，在 Companion 域
演进（多 bond + 当前活跃 ID），禁止写死「全局永远只有一个」的业务常量，也禁止复活酒馆大厅。

---

## 4. 运行主路径

```text
底栏 AI伙伴 → CompanionHubPage（关系首页 UI）
  → CompanionChatLauncher → /ai-chat → CompanionChatPage
  → SSE /api/companion/chat/stream
  → 世界：Arena 营地页（lib/game/life + life_service；Life 旧 UI 已删除，2026-10）
```

- 展示 SSOT：`/api/companion/state`（moments / moodThought / greeting 由 `CompanionStateData` 解析）。
- 页面类名 `CompanionHubPage`（`lib/pages/ai/companion_hub_page.dart`），对外文案「AI伙伴」。
- 照料走 `LifeService`（旧 `LifeProvider` 已随 Life 旧 UI 删除）；Flame 只负责渲染。
- 版本元数据与业务身份统一走 `/api/companion/*`。

**绑定联动（必守）**：`companion.life_entity_id` = 当前伙伴在世界里的居民。
进「TA 的世界」必须对焦该 ID；Hub 世界条只展示已绑定居民，未绑定不得假装 `entities.first` 就是 TA。

**双层身份（决策 12/13）**：

- 关系层：`name` / `emoji` / `avatar_url` / `persona`（用户自定义，聊天/Hub 用）。
- 世界层：绑定居民仅是舞台与照料载体；`bindLifeEntity` **禁止**用居民名/emoji 覆盖关系层。
- 不做 Live2D / 角色卡大厅（除非改写决策 13）。

---

## 5. 统一事件主线（CompanionEvent）

跨模块互动统一转换为 `CompanionEvent`，由后端持久化并投影到各页面：

```text
用户行为 / 社交行为 / Life Tick / 系统时间
        ↓  CompanionEvent（含 event_id / event_type / source_domain / dedupe_key /
          visibility / sensitivity / relationship_delta / occurred_at 等）
        ↓  Relationship + Memory + State 更新
        ↓  Daily Timeline / Chat Context / Proactive Event
        ↓  Hub / Feed / Notification / World
```

首批事件类型：`chat_turn_completed`、`memory_created/confirmed/corrected`、
`memory_conflict_detected`、`relationship_level_up`、`post_created/liked`、`commented`、
`life_moment_created`、`life_care_completed`、`proactive_scheduled/delivered/read`、
`voice_turn_completed`。

已落地事实：

- 聊天、记忆、关系升级、Life moment、主动消息已写入 `CompanionEvent`；`dedupe_key` + 来源字段 +
  用户级隔离保证可追踪；`companion_events` 表迁移须先在测试库执行。
- 记忆冲突用同一业务去重键写冲突记录与事件，重复提取不重复产生跨页面事件。
- 社交域经可选观察器投影 `post_created/post_liked/comment_created/comment_liked`，
  只写来源 ID 与统计元数据，不写正文。
- Life 普通 Tick（`eating`、`wandering` 等）只更新本地状态，**不**投影为跨域事件；
  重要成长 / 关系 / 世界事件与用户照料才进入统一时间线。

---

## 6. 统一聊天上下文

每次聊天请求经后端 Context Orchestrator，Flutter 不得自行决定记忆与关系逻辑。上下文顺序固定：

1. 安全策略与系统约束
2. Companion 身份、用户自定义资料、表达风格
3. 当前关系阶段、情绪、场景与 Life 状态
4. 已确认长期记忆（置顶记忆注入时标【置顶】）
5. 待确认记忆候选（默认不作为事实表达）
6. 最近对话与未完成话题
7. 本次输入 / 语音转写
8. 可用工具与权限

记忆流水线：`候选 → 去重/冲突检测 → 用户确认或低风险自动确认 → 注入上下文`；
用户删除/修正记忆必须立即影响后续对话。关系事件与确定性未完成话题已纳入后端唯一
`ContextSnapshot`，聊天 Prompt 与主动回访共享同一上下文。

模型配置：优先使用用户当前选中的 Provider/Base URL/模型/API Key，按请求覆盖全局 `llm_inference`
配置；API Key 只随请求传输，不写入 profile / 记忆 / 关系事件，不进日志与错误文案；调用失败回退
全局配置，不阻断关系数据写入。

---

## 7. 主动陪伴与通知

主动事件沿 `proactive_scheduled → proactive_delivered → proactive_read` 推进；
失败写 `proactive_delivery_failed`（不消耗每日额度）；撤回只追加 `proactive_revoked` 事件，
不删除历史。状态可从持久事件重建，服务重启不依赖内存；启动后优先恢复未过期 `scheduled` 事件，
沿用原 delivery key 重试。

已落地：

- 久未聊天 >24h 且冷却已过时，WS 发送带历史上下文的回访并写通知中心。
- 用户开关、免打扰时段、设备时区、每日上限；普通资料保存不覆盖主动配置。
- 通知中心经 `/api/companion/proactive/{notification_id}/read` 写已读回执（旧接口兼容）；
  通知 ID 同步进 `proactive_delivered` 事件与 WS 负载。
- 无远程推送时保持 WS + 本地通知降级；冷启动点击通知先暂存 payload，待 Navigator 挂载后跳转并回写。
- WS 重连后从持久事件接口回放，客户端按事件 ID / `dedupe_key` 去重补齐断线期间状态。

待补：真正持久化调度任务、FCM/APNs 离线推送 provider、更细的频控配置。

---

## 8. 客户端结构

| 组件 | 职责 |
|------|------|
| `CompanionService` | HTTP、SSE、DTO 转换 |
| `CompanionWsService` | `/ws/companion` 连接、心跳、退避重连、轻量事件分发 |
| `CompanionPresenceProvider` | 全局角标与存在感（登录 start / 登出 stop） |
| `CompanionHubViewModel` | Hub 投影与导航；订阅事件并合并刷新 |
| `CompanionInteractionCoordinator` | 广播流承载聊天完成 / 记忆变更 / 存在事件；有界去重；串联跨页面刷新与深链 |

规则：页面不得直接调 `ApiService`，不得自行拼 Prompt、改亲密度或写记忆；
WS 只更新轻量状态与注意力，不触发全量刷新；聊天完成事件不携带正文（避免敏感内容跨页面传播）；
Hub 卡片必须能跳回原始来源（聊天 / 帖子 / 记忆 / 世界 / 通知）。

---

## 9. 已落地迭代记录

### 9.1 互动闭环切片（Slice-1 ~ 16，均已落地）

| 切片 | 内容 |
|------|------|
| 1 | moments 解析进日常流；日常四类深链；绑定实体照料语气；世界「和 TA 聊天」CTA；Hub 返程刷新 |
| 2 | WS 客户端 + Presence Provider；底栏角标 / Hub「TA 想你了」/ 首页按需提醒 Sheet；聊天已读清角标 |
| 3 | 聊天 +2 / 照料 `intimacy/bump` 亲密度；社区 bot 自动创建；删死代码 `companion_context` |
| 4 | 记忆专页 `/ai-memories`；日常流 memory 深链 +「和 TA 聊聊这件事」 |
| 5 | 角色卡轻量导入（ST JSON/PNG → 关系层人设；不写酒馆 Agent、不导 Lorebook） |
| 6 / 6.1 | 记忆删除 / 置顶 / 编辑；置顶注入标注；轻量语音（本机 STT/TTS，气泡朗读）；迁移 `companion_memories.pinned` |
| 7 / 8 | 关系阶段进 Prompt（`backend/internal/biz/companion/llm.go`）；关系事件持久化 `companion_relationship_events` 并入日常流 |
| 9 / 10 | 记忆规范化去重 + `memory_key` + 用户确认；首页今日关系摘要 + 未完成话题轻提示 |
| 11 / 12 | 主动回访基础（见 §7）；用户 Provider 覆盖全局推理配置 |
| 13 ~ 16 | 场景化摘要标签；时间/情绪/节日 Prompt 行为与情绪修复规则；场景启动器（睡前/安抚/约会/学习）；多轮场景会话（场景 ID 随 SSE 传递、白名单、可退出） |

### 9.2 整体联调基础（对应原集成方案 Phase 1，已落地）

- `CompanionInteractionCoordinator` 与统一事件信封（见 §8）；聊天页 SSE done 后发统一完成事件；
  记忆 ViewModel 增删改 / 确认后发布变更事件并订阅后端事件防抖刷新。
- Hub 日常流展示未完成话题，点击复用聊天入口预填草稿（用户确认才发送，无第二套会话页）。
- Hub 首屏关系温度快捷入口；主动消息未读时展示「TA 想和你说」卡并切换主 CTA 为「回复 TA」。
- 主动配置 / 亲密度更新先确认 Profile 存在再写字段，避免假成功。

---

## 10. 未完成里程碑与下一步

按优先级（与原 roadmap / product-plan 阶段对应）：

1. **记忆质量**：复杂语义矛盾识别、敏感级别、更强置信度策略（结构化记忆判定）。
2. **主动陪伴产品化**：持久化调度任务、FCM/APNs provider、可配置频控（当前为「持久事件投递 + 兼容通知/WS」过渡态）。
3. **语音闭环**：连续语音、打断、情绪化 TTS、语音历史；弱网重试（现仅本机短轮次 STT/TTS）。
4. **多模态**：图片理解 / 伙伴自拍与图片回复（当前消息契约仍是文本，先不伪造图片理解）。
5. **场景深化**：睡前 / 安抚 / 约会 / 学习流程完整闭环（开场与多轮已落地基础版）；纪念日内容。
6. **安全与运营**：AI 标识、未成年人与敏感内容保护、记忆导出 / 清空、审计、Companion 专属指标。
7. **多 bond（决策 B）**：未开工；勿把世界地图点选误当成多会话已完成。

明确不做：复活酒馆大厅 / 双栈；Live2D / VRM 大厅（除非改写决策 13）；私信与 Companion 聊天合表；
前端决定长期记忆、亲密度、主动消息；用情绪勒索 / 诱导付费制造留存。

---

## 11. 关键指标

首次聊天完成率；次日 / 七日 Companion 留存；每日有效对话轮数；记忆命中率 / 重复率 / 纠错率；
主动消息打开率 / 回复率 / 关闭降频率 / 重复发送率；语音与场景完成率；
Hub / 聊天 / 通知 / 世界的事件一致性与端到端延迟。

---

## 12. 回滚

UI 与协调器层为纯 Flutter 展示与导航增强，关 Flag / 回退提交即可；Companion 新增表均向后兼容，
回滚应用代码不需删表。**不要**回滚为固定用户 ID 或信任客户端 `user_id` 的实现。
