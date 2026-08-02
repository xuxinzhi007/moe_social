# AI Companion App 整体联调方案

## 1. 目标

将 Feed、好友、私信、AI Companion、Life 世界、记忆、通知、语音和 AI 工具整合为一条产品体验：

> 用户在 Moe Social 里生活，TA 了解用户、记得经历、参与日常，并在合适的地方出现。

Companion 不是一个孤立的聊天产品，也不是替代社交主线的 AI 大厅。社交仍然是 App 主入口，Companion 是贯穿各业务域的关系层，Life 是关系内容的可视化舞台。

## 1.1 升级原则

本方案是对现有系统的增量升级，不是回退、重写或推倒重来。

- 保留现有 App Shell、社交主线、路由、Provider、Companion Hub、聊天页和 Life 能力。
- 保留现有 Companion Profile、State、Memory、Chat History、SSE、WS、亲密度、主动回访和 STT/TTS 实现。
- 优先通过事件、上下文编排和协调器把已有模块串起来，不优先替换已有页面或协议。
- 新增 API 和字段保持向后兼容；已有接口只有在无法满足联调时才扩展，不直接废弃。
- 每个阶段都必须可独立运行、可回滚，并且先验证旧链路仍然可用。
- AIRI、SillyTavern 等项目只作为交互和架构参考，不作为当前 App 的替换底座。

当前系统的演进关系是：

```text
现有 Companion 能力
  + 事件统一
  + 上下文统一
  + 跨页面协调
  + 数据一致性与可观测性
  = 整体升级后的 Moe Social
```

## 2. App 分层

```text
App Shell
├── 社交层：Feed / 好友 / 私信 / 社区
├── 关系层：Companion Profile / Relationship / Memory / Consent
├── 智能层：Context Orchestrator / LLM / Tool / Safety
├── 存在层：Presence / Proactive Event / Notification / Voice
└── 世界层：Life Entity / World State / Pet Avatar / Scene
```

### 2.1 职责边界

| 层 | 负责内容 | 不负责内容 |
|---|---|---|
| 社交层 | 用户产生的帖子、评论、好友和私信 | 直接拼接 Companion Prompt |
| 关系层 | TA 身份、亲密度、关系事件、记忆生命周期 | 直接调用具体 LLM Provider |
| 智能层 | 上下文编排、模型调用、工具调用、内容安全 | 决定 UI 页面和导航 |
| 存在层 | 主动问候、WS、通知、语音状态 | 保存未经确认的长期事实 |
| 世界层 | Life 居民、状态、场景和渲染 | 作为多角色聊天列表 |

所有关系规则由后端 Companion 域决定，Flutter 只负责展示、交互和导航。

## 3. 统一数据主线

所有跨模块互动都转换为 `CompanionEvent`，由后端持久化并按需投影到不同页面。

```text
用户行为 / 社交行为 / Life Tick / 系统时间
              ↓
        CompanionEvent
              ↓
  Relationship + Memory + State 更新
              ↓
  Daily Timeline / Chat Context / Proactive Event
              ↓
       Hub / Feed / Notification / World
```

事件至少包含：

- `event_id`、`user_id`、`companion_id`、`event_type`、`occurred_at`
- `source_domain`、`source_id`、`payload`
- `visibility`、`sensitivity`、`dedupe_key`
- `relationship_delta`、`memory_candidate`、`follow_up_at`

首批事件类型：

- `chat_turn_completed`
- `memory_created`、`memory_confirmed`、`memory_corrected`
- `memory_conflict_detected`
- `relationship_level_up`
- `post_created`、`post_liked`、`commented`
- `life_moment_created`、`life_care_completed`
- `proactive_scheduled`、`proactive_delivered`、`proactive_read`
- `voice_turn_completed`

## 4. 统一聊天上下文

Companion 聊天每次请求都经过后端 `Context Orchestrator`，禁止 Flutter 自己决定记忆和关系逻辑。

上下文顺序固定为：

1. 安全策略和系统约束。
2. Companion 身份、用户自定义资料和表达风格。
3. 当前关系阶段、情绪、场景和 Life 状态。
4. 已确认的长期记忆。
5. 待确认的记忆候选，默认不作为事实表达。
6. 最近对话和未完成话题。
7. 本次用户输入、图片或语音转写结果。
8. 可用工具及工具调用权限。

记忆采用：`候选 → 去重/冲突检测 → 用户确认或自动低风险确认 → 注入上下文`。用户删除或修正记忆后，必须立即影响后续对话。

## 5. 页面与业务联调

### 5.1 Companion Hub

- 只展示一个当前 Companion。
- 聚合关系摘要、今日事件、未完成话题、记忆入口和 Life 入口。
- WS 只更新轻量状态和注意力，不触发全量页面刷新。
- 所有卡片必须能跳转到原始来源：聊天、帖子、记忆、世界或通知。

### 5.2 Feed / 社区

- 用户发布内容后生成 `post_created` 事件。
- Companion 可以基于用户明确授权参与草稿、情绪回应或回顾。
- 不默认让 Companion 公开发帖，不伪装真人账号。
- AI Bot 账号必须显示身份标识，并与用户 Companion 身份隔离。

### 5.3 私信 / 好友

- 私信仍是人与人社交，不与 Companion Chat 合并会话表。
- Companion 可从通知或关系 Hub 提供“和 TA 讨论这件事”的深链。
- 私信内容进入 Companion 上下文必须有明确授权和敏感级别控制。

### 5.4 Life 世界

- Life Entity 是 Companion 的世界投影，不是第二套人格。
- Companion Profile 保存关系身份；Life Entity 保存世界状态和渲染数据。
- Life Tick 产生事件，事件反向影响 Hub、日常流和主动行为。
- 世界入口只围绕当前 Companion，不演进为酒馆式多角色大厅。

### 5.5 通知与主动陪伴

- 主动消息必须有触发原因、优先级、冷却时间和撤回/降频能力。
- App 内 WS、通知中心和离线推送使用同一 `ProactiveEvent`。
- 推送状态必须持久化，避免服务重启后重复发送。
- 用户关闭主动联系后，聊天和被动状态展示仍然可用。

### 5.6 语音

- 第一阶段采用短轮次：录音 → STT → Companion Chat → TTS。
- 文本聊天和语音聊天共用同一个会话、记忆、亲密度和关系事件。
- 语音失败自动回退文本，不阻塞聊天主链路。
- 后续再增加 VAD、打断、连续语音和情绪化 TTS，不提前引入 Live2D。

## 6. API 与客户端结构

后端继续以 `backend/api/companion/v1/companion.proto` 为契约 SSOT，建议新增或补齐：

- `GET /api/companion/timeline`：统一关系时间线。
- `GET /api/companion/context/preview`：调试当前请求实际使用的上下文摘要。
- `GET /api/companion/events`：分页查询关系事件。
- `GET /api/companion/proactive-deliveries`：从持久 `CompanionEvent` 重建主动投递状态，供通知/联调使用。
- `POST /api/companion/proactive/revoke`：追加撤回事件，不删除历史，旧通知接口保持兼容。
- `POST /api/companion/proactive/{id}/read`：主动消息已读回执。
- `POST /api/companion/voice/turn`：可选的语音轮次统一入口。

Flutter 侧保持：

- `CompanionService`：HTTP、SSE 和 DTO 转换。
- `CompanionWsService`：连接、心跳、重连和轻量事件分发。
- `CompanionPresenceProvider`：全局角标和存在感。
- `CompanionHubViewModel`：Hub 投影和导航。
- 新增 `CompanionInteractionCoordinator`：串联聊天完成后的刷新、语音状态、事件回执和跨页面深链。
- `CompanionService.getContextPreview`：读取后端统一上下文的安全元数据，不返回 Prompt 或聊天正文，并返回关系事件数量用于联调校验。

页面不得直接调用 `ApiService`，也不得自行拼装 Prompt、修改亲密度或写入记忆。

## 7. 统一联调场景

### 场景 A：普通聊天

```text
输入 → SSE 流式回复 → 保存 ChatLog → 亲密度更新
     → 异步记忆候选 → Hub 刷新 → 关系事件/时间线更新
```

### 场景 B：社交内容联动

```text
发布帖子 → 产生 post_created → Companion 生成可选回应
         → 用户确认 → Feed/通知展示 → 进入日常时间线
```

### 场景 C：Life 联动

```text
Life Tick / 照料 → life_moment_created → 状态与日常流更新
                 → Companion 可在下一次聊天或主动消息中自然提及
```

### 场景 D：离线回访

```text
超过冷却时间 → 选择未完成话题/记忆/关系事件
             → 主动事件 → WS 或通知 → 点击后回到同一 Companion 会话
```

### 场景 E：语音陪伴

```text
按住说话 → STT → 同一 ChatStream → TTS 播放
         → 文本/语音历史统一 → 记忆和关系更新一致
```

## 8. 实施顺序

### Phase 1：统一联调基础

- 建立 `CompanionEvent` 和 `ProactiveEvent` 数据模型。
- 将聊天、记忆、关系升级、Life moment 统一写入事件流。
- 增加事件去重、来源追踪和用户级隔离。
- 增加聊天完成后的统一客户端协调器。

当前已落地的第一步：

- Flutter 新增 `CompanionInteractionCoordinator`，以广播流承载聊天完成、记忆变更和存在感事件。
- Companion WS 事件补齐 `dedupe_key`、安全 payload、可见性、敏感级别和发生时间，并投影到同一客户端事件信封，支持跨页面一致刷新与去重。
- 客户端协调器按后端事件 ID 或 `dedupe_key` 做有界去重，WS 重连或重复投递不会触发重复跨页面刷新。
- `CompanionChatPage` 在 SSE `done` 后发布统一聊天完成事件，不携带聊天正文，避免跨页面传播敏感内容。
- `CompanionMemoriesViewModel` 在删除、置顶、编辑和确认后发布记忆变更事件。
- `CompanionMemoriesViewModel` 同时订阅后端记忆事件，聊天异步提取或冲突生成后会防抖刷新记忆与冲突列表。
- `CompanionHubViewModel` 订阅事件并合并刷新请求，继续复用现有 `/api/companion/state`、历史、记忆和关系事件接口。
- 现有 WS 存在感仍由 `CompanionPresenceProvider` 处理，统一事件只作为跨模块通知，不替换现有连接逻辑。
- 后端已将聊天、记忆、关系升级、Life moment 和主动消息写入 `CompanionEvent`，通过 `dedupe_key`、来源字段和用户隔离保证可追踪性。
- 记忆冲突使用同一业务去重键写入冲突记录和 `memory_conflict_detected` 事件，重复提取不会重复生成跨页面事件。
- 社交域通过可选观察器投影 `post_created`、`post_liked`、`comment_created` 和 `comment_liked`；只写入来源 ID 与统计元数据，不写入帖子/评论正文。
- 主动消息沿 `proactive_scheduled → proactive_delivered → proactive_read` 状态推进；投递失败写入 `proactive_delivery_failed`，不会消耗有效的每日投递额度。
- 通知中心通过兼容的 `/api/companion/proactive/{notification_id}/read` 回执接口写入主动消息已读事件，原通知接口继续保留。
- 本地主动通知携带通知 ID，点击后复用现有 `/ai-chat` 路由进入 Companion 会话并回写已读回执；无远程推送时仍保持 WS + 本地通知降级链路。
- 冷启动点击通知时，客户端会暂存 Companion payload，等待现有 Navigator 挂载后再跳转和回写，避免启动时序导致主动消息丢失。
- Companion WS 重连成功后会从持久化事件接口回放最近事件，协调器按事件 ID/去重键过滤重复投递，补齐断线期间 Hub、通知和 Life 的状态变化。
- Hub 日常流会展示明确标记的未完成话题，点击复用现有 Companion 聊天入口并把原话题预填为草稿；用户确认后才发送，不新增第二套会话页面。
- Hub 首屏新增关系温度式快捷入口和状态反馈：继续聊天、记忆、Life 世界可直接触达；有新互动时关系卡片会增强边框/光晕，状态文案使用轻量过渡。
- Companion 首页在主动消息未读时展示“TA 想和你说”内容卡，并将唯一主聊天操作切换为“回复 TA”。
- 记忆页把待确认、已确认和冲突的影响直接写入状态卡；聊天页展示倾听、组织回应和流式续写状态，并遵循系统“减少动效”设置。
- 主动投递成功后，通知 ID 同步写入 `proactive_delivered` 事件和 WS 负载，Hub、通知中心与时间线使用同一个关联标识。
- 每日主动额度以持久化 `proactive_delivered` 事件为准，不再用任意旧通知提前拦截；投递失败会释放本次预占额度，旧通知链路继续可读。
- 主动配置与亲密度更新先确认 Companion Profile 存在，再执行字段更新，避免返回成功但数据未落库。
- 主动投递状态可从 `scheduled`、`delivered`、`failed`、`read` 事件重建，服务重启不依赖内存状态。
- 服务启动后的主动投递周期会优先恢复未过期的 `scheduled` 事件，沿用原 delivery key 重试，避免重启时重新创建同一主动任务。
- 主动状态投影支持 `priority`、`expires_at` 和 `proactive_revoked`；撤回只追加事件，不删除既有通知/审计记录。
- 通知 Provider 在新状态接口不可用时回退旧通知 API；可用时自动隐藏已过期或已撤回的主动通知。
- Life 普通 Tick 仅更新 Life Provider 本地状态，关键事件才通过协调器触发 Hub/通知等跨域刷新，避免高频全量请求。
- Life 的 `eating`、`wandering` 等常规事件不会投影为跨域 CompanionEvent；重要成长、关系、世界事件和用户照料才进入统一时间线。
- 主动陪伴配置使用独立更新路径，普通 Companion 资料保存不会覆盖启用状态、每日上限、免打扰时段和时区配置。

Phase 1 基础联调已具备可回归实现；主动投递状态投影已支持按优先级和计划时间排序，Phase 3 目前仍是“持久事件投递 + 兼容通知/WS”的过渡态，真正的持久化调度任务和离线推送 provider 仍需后续补齐。新增 `companion_events` 表必须先在测试库执行迁移，生产库不在本阶段自动改表。

下一步将继续完善主动消息的持久化调度、撤回/过期和离线推送策略；客户端协调器作为兼容层存在，不改变现有 API 契约。

验收：一次聊天结束后，Hub、记忆、关系事件、通知角标和 Life 状态能够一致刷新。

### Phase 2：关系与记忆增强

当前进度：关系事件和确定性未完成话题投影已纳入后端唯一 `ContextSnapshot`，聊天 Prompt 与主动回访会共享这些上下文；记忆冲突已具备持久化、查询以及接受/拒绝处理。未完成项仍包括更精细的语义话题抽取、真正持久化调度任务、FCM/APNs provider、测试库迁移和真实端到端 API 联调。

- 补齐关系阶段 Prompt 行为和未完成话题。
- 实现记忆冲突、过期、置信度和用户确认反馈。
- 日常流升级为关系时间线，而不是多来源卡片简单拼接。

验收：用户修改一条记忆后，下一轮聊天和 Hub 摘要不再使用旧内容。

### Phase 3：主动陪伴产品化

- 将主动触发从内存冷却升级为持久化任务和事件状态机。
- 打通 App 内通知、WS、离线推送和已读回执。
- 增加用户时区、免打扰、每日上限、降频和重复检测。

验收：重启服务、断线重连和重复打开 App 都不会重复推送同一主动事件。

### Phase 4：语音与多模态

- 统一语音轮次与文本会话。
- 增加图片理解和图片回复的上下文入口。
- 引入场景模板：早晨、睡前、安抚、约会、学习/工作。

验收：文本、语音、图片三种输入可以在同一关系上下文中连续对话。

### Phase 5：运营、安全和商业化

- AI 身份标识、敏感内容、安全回复和未成年人保护。
- 记忆导出、删除、全量清空和主动消息控制。
- 记录模型、Prompt 版本、上下文摘要、失败原因和用户反馈指标。

验收：线上问题可以追踪到用户、会话、模型、策略和事件版本。

## 9. 暂不做

- 不恢复 AI 酒馆作为主入口。
- 不把 Life 地图做成多会话/多 Companion 大厅。
- 不立即做 Live2D、VRM 或复杂桌面 VTuber Stage。
- 不把社交私信和 Companion 聊天合并为一张消息表。
- 不允许前端直接决定长期记忆、亲密度和主动消息。

## 10. 统一验收指标

- 首次聊天完成率、次日/七日 Companion 留存。
- 记忆命中率、重复率、纠错率和用户确认率。
- 主动消息打开率、回复率、关闭/降频率和重复发送率。
- 聊天、语音、图片场景完成率。
- Hub、聊天、通知、Life 的事件一致性和端到端延迟。
