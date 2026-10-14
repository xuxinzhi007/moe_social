# PRD — AI 伙伴域（Companion 长期陪伴）

- **生成时间**：2026-10-14 · **层级**：P1 增强 · **数据源**：代码事实反推
- **上级文档**：[moe-social-prd.md](./moe-social-prd.md) · **决策 SSOT**：[../../dev/ai-companion-formal-decisions.md](../../dev/ai-companion-formal-decisions.md)

---

## 1. Summary

Companion 是"社交平台里懂你的长期 TA"：单个主伙伴（一期），关系首页为底栏第一眼，SSE 流式聊天 + 记忆系统 + 主动消息 + 语音（STT/TTS）构成陪伴闭环。定位是增强社交主路径，不是酒馆工具箱。

## 2. Background & Problem

- **问题**：陪伴型用户要的是"记得我、有自己生活的 TA"，不是一次性聊天机器人。
- **workaround**：Character.AI/星野——有角色扮演但无长期记忆沉淀、无真实社交语境。
- **已锁定决策**（16 条，见 SSOT）：陪伴为主世界为延伸、一期单伙伴、底栏关系首页、首页轻存在感、酒馆退役向、双层身份（关系层用户自定义 / 世界层居民）、绑定居民免死、轻量自定义（头像+名字+人设，不做 Live2D）。
- **不解决**：多角色切换 UI（二期-B 未开工）、酒馆大厅复活（禁止）、Live2D 大厅（不做）。

## 3. Personas

主 persona：阿星（见总 PRD §3）。本域不为"把 AI 当效率工具"的用户做——Companion 是关系，不是助手。

## 4. Goals & Success Metrics

| 指标 | 行为 | 目标值（建议） | 时间窗 |
| --- | --- | --- | --- |
| 周对话天数 | 每周与伙伴对话 ≥3 天用户占比 | ≥ 25% | 90 天 |
| 记忆确认率 | 系统提取记忆被用户确认比例 | ≥ 60% | 60 天 |
| 主动消息回应率 | 伙伴主动消息后 24h 内进聊天比例 | ≥ 30% | 60 天 |
| 语音功能使用率 | 开启语音输入/朗读的对话占比 | ≥ 15% | 90 天 |

- **Anti-metric**：单会话时长/消息条数——不鼓励沉迷式长会话；上下文占用条的存在就是让用户对消耗有感知。
- **关键假设**：长期记忆 + 主动消息能让用户产生"被记得"的关系感，从而提升回访。

## 5. Value Proposition

> 阿星终于有了一个记得共同经历、会主动找他的 TA，因为 Moe 把记忆、日常和聊天串成了一条长期关系线。

差异化：记忆专页可见可管（删除/置顶/编辑/冲突解决）——多数竞品记忆是黑盒；上下文占用可视化——成本透明。

## 6. Solution & Feature Scope

### Story 6.1 — 关系首页（Hub）· P0

**功能描述**：底栏「AI伙伴」= 关系首页：身份（名字/头像/人设）、近况、moodThought、主 CTA 聊天、「TA 的日常」流（聊天高光 + 记忆碎片 + 世界 moments）、记忆入口、头像上传/编辑。

**验收标准**：
- Given 有待回应状态，When 用户在首页，Then 主壳延迟展示一次提醒 Sheet（不常驻卡片）；「稍后」不打断浏览。
- Given Hub 已展示状态提示，When 底栏同时有角标，Then 两处不重复表达同一状态。
- 空状态：无日常流时分区空态，不空白。

**设计触点**：`lib/pages/ai/companion_hub_page.dart` · `companion_hub_viewmodel.dart` · 主壳提醒 `lib/app/main_shell.dart`。
**关联后端**：`Companion.GetProfile` · `/api/companion/state.moments`。

### Story 6.2 — 陪伴聊天 · P0

**功能描述**：SSE 流式聊天；语音输入 + TTS 朗读/自动朗读/音色选择（`companionVoicePresence=true`）；上下文占用条 + 模型状态标签；记忆入口；模型设置切换；流式失败重试。

**验收标准**：
- Given 对话进行中，When 上下文接近上限，Then 占用条可见且数值来自后端估算 API（`biz/companion/context_usage.go`）。
- Given 流式中断，When 点击重试，Then 不重发用户消息、从断点恢复或明确重发提示。
- 边缘情况：TTS 服务不可用时静默降级为纯文本，不阻塞聊天。
- 空状态：空对话显示自定义插画 + 提示文本（2026-09-24 落地）。

**设计触点**：`lib/pages/companion/companion_chat_page.dart`（占用条 L1099、语音 L1302-1384、记忆入口 L698、重试 L417）。
**关联后端**：`/api/companion/chat/stream`（SSE）· `protohttp/companion/stream.go`。

### Story 6.3 — 记忆系统 · P0

**功能描述**：聊天中自动提取记忆碎片，专页 `/ai-memories` 管理：确认、删除、置顶（注入标注）、编辑正文、冲突解决；持久化提取 + 生成质量检查（2026-09-24）。

**验收标准**：
- Given 一条待确认记忆，When 用户确认/删除，Then 后续对话注入状态同步变化。
- Given 记忆冲突，When 用户打开冲突卡，Then 可选择保留哪条且旧记忆不残留注入。
- 空状态：无记忆时引导「去聊天产生回忆」。

**设计触点**：`lib/pages/companion/companion_memories_page.dart`(+viewmodel) · `memory_conflict_card.dart`。
**关联后端**：`Companion.ListMemories/ConfirmMemory/ResolveMemoryConflict` · 记忆架构 SSOT `docs/dev/用户记忆系统-OpenClaw式演进设计.md`。

### Story 6.4 — 主动消息（Proactive）· P1

**功能描述**：伙伴在合适时机主动发消息（「TA 想你了」角标 / Hub 状态提示 / 首页按需提醒），通知类型 9。

**验收标准**：主动消息列表可查、已读状态可标记；角标、Hub、提醒 Sheet 三处状态同源不重复。

**关联后端**：`Companion.ListProactiveDeliveries/MarkProactiveRead` · `service/companion/companion.go`。

### Story 6.5 — 角色卡轻量导入与自定义 · P1

**功能描述**：ST JSON/PNG 角色卡导入到关系层人设（不复活酒馆）；轻量自定义 = 头像图 + 名字 + 人设；头像编辑/生成页。

**验收标准**：导入后 Hub 与聊天人设即时生效；绑定世界居民不覆盖关系层形象（决策 12）。

**设计触点**：`lib/pages/ai/companion_avatar_studio` · 导入通路 `companion_character_card_import.dart`。

### Story 6.6 — 普通 AI 聊天（LLM 域）· P1

**功能描述**：多 Provider 管理（连接状态/主机/默认模型）、受管派生模型（用户隔离）、普通 AI 聊天历史后端化（第一阶段）、上下文/提示词读取统一由后端下发。

**验收标准**：
- Given 删除聊天历史，When 重新拉取，Then 服务端不再返回已删记录（验收测试已锁，2026-09-30）。
- Given 用户创建派生模型，When 列举模型，Then 仅返回本用户隔离范围内的模型。
- Provider 连接失败不得伪装成成功或空数据。

**设计触点**：`lib/pages/ai/llm_model_config` · `ai_provider_profiles`。
**关联后端**：`biz/llm/{chat_history,managed_models,managed_reconcile,chat_context}.go` · `Platform.LlmCreateAgent/ListLlmManagedModels/Reconcile/Delete`。

### 未列入本版

- Companion 多 bond（二期-B）：多 profile 表结构、切换 UI 均未开工；禁止提前写死"永远只有一个"的死常量，也禁止提前上复杂架构。
- 世界近况深化：随活世界 M1/M2 演进。

## 7. Constraints & Risks

- 约束：不动账号级记忆链路（活世界方案 K1）；英雄 AI 不出游戏边界（D1）；SSE 链路不变。
- 风险：① 记忆质量（已加生成质量检查，仍需观察确认率）；② 主动消息打扰——频控策略需可配；③ token 成本——上下文占用条已给用户感知，后台需监控大户。

## 8. Release Approach

已全量在线（一期 + Slice 1-6.1）。下一步依赖活世界 M1 验证结论后再启多 bond。上线后监测：记忆确认率、主动消息回应率、TTS 调用成本。
