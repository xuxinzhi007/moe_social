# AI 陪伴互动闭环（迭代方案）

> **日期**：2026-07-31  
> **状态**：迭代中 · Slice-1～6 已落地（记忆管理 + 轻量语音，2026-08-01）  

> **决策 SSOT**：`docs/dev/ai-companion-formal-decisions.md`  
> **边界**：`docs/dev/ai-companion-backend-boundary.md`  
> **Flame 舞台**：`.cursor/skills/flame-life-world/SKILL.md`

---

## 1. 背景

一期关系首页 + 聊天 SSE +「TA 的世界」已通；二期-A 日常流（聊天高光/记忆）已并入。  
当前缺口是**同一 TA 在照料 / 状态 / 聊天 / 日常之间感觉断开**：

- 照料回复是硬编码文案，不读 companion state
- 后端 `state.moments` Flutter 未解析
- 日常流多数条目不可点进
- 世界页无「去聊天」；从聊天返回依赖手动刷新（世界已有）
- WS 问候 / 亲密度增长 / 多 bond 仍后置

目标：持续迭代「活着的长期 TA」，**不**复活酒馆、**不**误开工多 bond。

---

## 2. 产品边界（不变）

| 是 | 不是 |
|----|------|
| 单活跃伙伴闭环 | 多 bond UI（决策 B，未开工） |
| 关系首页第一眼 | 酒馆选卡大厅 |
| 世界 = 延伸舞台 | 地图点选 = 多会话 |

---

## 3. 迭代切片

### Slice-1（已落地）照料—状态—聊天—日常闭环

| 项 | 验收 |
|----|------|
| moments | ✅ `CompanionStateData` 解析；Hub 日常流优先展示 |
| 日常深链 | ✅ `world`/`moment`→世界；`memory`→全文 sheet；`post`→详情；`chat`→会话 |
| 照料语气 | ✅ 绑定实体 feed/pet 优先 `moodThought`/`greeting` |
| 世界 CTA | ✅ 绑定实体 Sheet「和 TA 聊天」 |
| Hub 刷新 | ✅ 聊天/世界返回 `loadDashboard` |

**不做本切片**：Flutter Companion WS、亲密度服务端增长、多 profile、记忆专页。

### Slice-2（已落地）实时存在感

| 项 | 验收 |
|----|------|
| WS 客户端 | ✅ `CompanionWsService` → `/ws/companion`（subscribe/ping、退避重连） |
| Presence | ✅ `CompanionPresenceProvider` 全局；登录 start / 登出 stop |
| Hub / 首页 | ✅ 问候/mood/activity 实时补丁；首页不常驻卡片，仅在待回应时按需提醒 |
| 角标 | ✅ 底栏 AI伙伴 badge；Hub 状态提示；首页一次性提醒 Sheet；聊天已读清除 |
| 聊天 AppBar | ✅ SSE done 后刷新 companion state |

### Slice-3（已落地）关系进度 + 收口

| 项 | 验收 |
|----|------|
| 聊天亲密 | ✅ ChatStream 成功后 +2；等级每 10 点 +1（上限 10） |
| 照料亲密 | ✅ `POST /api/companion/intimacy/bump`；绑定实体 feed/pet 调用 |
| 社区 bot | ✅ 缺失时自动创建 bot 用户并同步头像/签名 |
| 死代码 | ✅ 删除 `companion_context.dart` |

### 明确延后

- 多 bond（决策 B）
- 酒馆复活
- 主动发帖 / 外联推送产品化

---

## 4. 架构（Slice-1）

```text
CompanionService.getSnapshot()
  └─ state.moments / moodThought / greeting
        │
        ├─ CompanionHubViewModel → 日常流 + Hero
        ├─ LifeWorldPage care → 语气 + 聊天 CTA
        └─ Daily tile → world / memory sheet / post detail / chat
```

原则：状态以 `/api/companion/state` 为展示 SSOT；Life 照料仍走 LifeProvider；Flame 只渲染。

**绑定联动（必守）**：`companion.life_entity_id` = 当前伙伴在世界里的居民。  
进「TA 的世界」必须对焦该 ID；Hub 世界条只展示已绑定居民，未绑定不得假装 `entities.first` 就是 TA。

**双层身份（决策 12/13）**：  
- 关系层：`name` / `emoji` / `avatar_url` / `persona`（用户自定义，聊天/Hub 用）  
- 世界层：绑定居民仅舞台与照料；`bindLifeEntity` **禁止**用居民名/emoji 覆盖关系层  
- 一期不做 Live2D / 角色卡大厅

---

## 5. 影响文件

- `lib/services/companion_service.dart`
- `lib/pages/ai/companion_hub_viewmodel.dart`
- `lib/pages/ai/companion_hub_page.dart`
- `lib/pages/life/life_world_page.dart`
- `docs/dev/ai-companion-formal-decisions.md`（进度勾选）

---

## 6. 回滚

纯 Flutter 展示与导航增强；关 Flag / 回退提交即可。无 DB 迁移。

---

## 7. Slice-1 验收清单

- [x] moments 解析并出现在日常流（或回退世界事件）
- [x] 日常流四类均可导航（post 无 id 时可跳过）
- [x] 绑定实体照料语气来自 companion state
- [x] 世界页绑定实体可进聊天
- [x] 聊天返回 Hub 自动刷新
- [x] `dart analyze` 相关文件无 error

## 8. Slice-2 验收清单

- [x] `/ws/companion` 连接 + 心跳 + 重连
- [x] greeting / state_snapshot 刷新 Hub Hero 与首页按需提醒状态
- [x] 底栏 AI伙伴角标 + Hub「TA 想你了」
- [x] 聊天已读 / 点横幅清角标
- [x] 聊天结束后 AppBar 活动态刷新

## 9. Slice-4（已落地）记忆专页

| 项 | 验收 |
|----|------|
| 入口 | ✅ Hub AppBar「TA 记得的事」→ `/ai-memories` |
| 日常流 | ✅ `memory` 条点进专页并高亮对应记忆 |
| 详情 | ✅ 点卡片看全文 +「和 TA 聊聊这件事」→ 聊天 |
| 列表 | ✅ 拉取最多 40 条；类型/重要度标签；下拉刷新 |

## 10. Slice-5（已落地）角色卡轻量导入

| 项 | 验收 |
|----|------|
| 入口 | ✅ Hub「自定义我的 TA」→「从角色卡导入」 |
| 格式 | ✅ ST V2/V3 JSON、扁平 Tavern JSON、Moe 导出卡、PNG `chara` tEXt |
| 映射 | ✅ name / persona / traits / system_prompt_override；PNG 可上传为头像 |
| 边界 | ✅ 不写酒馆 Agent、不导入 Lorebook / Character Book、需点「保存」才落库 |

## 11. Slice-6（已落地）记忆管理 + 轻量语音

| 项 | 验收 |
|----|------|
| 删除 | ✅ `DELETE /api/companion/memories/{id}`；专页确认后移除 |
| 置顶 | ✅ `POST .../pin`；`pinned` 字段；置顶→永久；列表置顶优先 |
| 语音 | ✅ Companion 聊天：麦克风听写 + 气泡朗读 + AppBar 自动朗读开关（`companionVoicePresence`） |
| 边界 | ✅ **不做 Live2D**；语音仅本机 STT/TTS（AIRI 向第一步） |

> 部署后需 `make db-migrate`（`companion_memories.pinned`）。

## 12. Slice-6.1（已落地）记忆编辑 + 体验打磨

| 项 | 验收 |
|----|------|
| 编辑 | ✅ `PUT /api/companion/memories/{id}`；专页「编辑这段记忆」 |
| Prompt | ✅ 置顶记忆注入时标【置顶】 |
| Hub | ✅ 无人设时 Hero「完善人设或从角色卡导入」 |
| 语音文案 | ✅ 麦克风权限/不可用时友好 Toast |
| 迁移 | ✅ `companion_memories.pinned` 已可 `make db-migrate` |

## 13. 下一刀建议

1. **Slice-7：关系阶段行为化**：关系等级进入 Companion Prompt，初识、熟悉、稳定联系、亲近阶段使用不同的连续性和主动性规则；高亲密阶段明确尊重用户边界。已落地于 `backend/internal/biz/companion/llm.go`。
2. **Slice-8：关系事件与里程碑**：首次聊天、关系升级持久化到 `companion_relationship_events`，并通过 `/api/companion/relationship-events` 接入 Hub 日常流。已落地。
3. **Slice-9：记忆质量基础**：自动提取记忆按类型和规范化正文去重；通过 `memory_key` 更新未确认的同一事实；记忆专页支持用户确认，确认记忆不会被自动覆盖。已落地。
4. **Slice-10：今日关系摘要**：首页根据关系事件、伙伴状态、记忆和聊天高光生成摘要；检测问号、计划词和回访词后展示“可以继续”的轻量话题提示。已落地。
5. **Slice-11：主动回访基础**：最近聊天超过 24 小时且冷却已过时，通过 WS 发送带最近话题的主动回访，并写入通知中心；客户端将 `proactive` 事件纳入未读提醒。已落地。
6. **Slice-12：用户 Provider 覆盖**：Companion 聊天读取用户当前选中的 Provider 配置，按请求覆盖后端全局推理；不持久化 API Key。已落地。
7. **Slice-13：场景化摘要细节**：摘要根据时间、周末和伙伴情绪显示早晨问候、睡前陪伴、周末陪伴或情绪安抚标签。已落地。
8. **Slice-14：场景与情绪修复行为**：聊天 Prompt 根据时间、周末、固定节日和伙伴状态改变语气；低落/冲突场景要求先承接、具体道歉、询问陪伴方式，避免说教和依赖施压。已落地。
9. **Slice-15：场景启动器**：聊天输入区提供睡前收尾、情绪安抚、轻松约会、专注学习四个场景开场，用户可修改后发送；不新增第二个聊天入口。已落地。
10. **Slice-16：多轮场景会话**：场景 ID 通过 SSE 请求持续传递到后端 Prompt；支持睡前、安抚、约会、学习四种白名单场景，用户可退出场景。已落地。
11. 图片理解/自拍暂缓：当前 Companion 后端消息契约仍是文本，先不伪造图片已被模型理解。
12. 复杂语义矛盾、敏感级别和更强的记忆置信度策略需要下一刀接入结构化记忆判定。
13. 离线推送、用户时区、免打扰和可配置频控仍需补齐。
14. AIRI 向形象（Live2D）仅在明确产品决策改写决策 13 后。
15. 多 bond（决策 B，勿误开工）。
