# Moe Brain · 记忆 RPG（Memory OS 游戏化层）

> **状态**：已实现（管理台 AI 大脑 · Tab「记忆 RPG」）  
> **最后同步**：2026-05-30  
> **关联**：[`llm-inference-and-memory-vision.md`](./llm-inference-and-memory-vision.md) · [`用户记忆系统-OpenClaw式演进设计.md`](./用户记忆系统-OpenClaw式演进设计.md)  
> **UI 入口**：管理台 → AI 大脑 → Tab「记忆 RPG」（与工作台、知识图谱并列，不替换原有表格）

## 1. 产品目标

把 Bot 自传 / 记忆整理包装成 **Memory RPG**：采集 → 分类 → 图谱 → consolidation → 注入 → 遗忘。  
用户以 **观察者** 身份看 Bot 在 2D 小世界里探索、思考、整理记忆；本地小模型可为主力，RPG 层通过 **异步 consolidation + 算法压缩** 补偿纯 LLM 润色，不阻塞发帖流水线。

## 2. 游戏循环

| 阶段 | 玩家动作 | 系统行为 | 现有能力映射 |
|------|----------|----------|--------------|
| Capture | 试跑发帖 | 写入 episode + 记忆 | `RunAgentOnce` / pipeline WS |
| Classify | 查看碎片背包 | 按质量分标记 solid / fragment / cracked | `EffectiveQuality` |
| Graph | 切到「知识图谱」Tab | 可视化 episode / tag / memory | `GetBrainGraph` |
| Consolidate | **入梦** / **压缩** / **整理碎片** | 润色、标记-清扫合并、写 dream log | `RunBrainDream` / `CompressBrainMemories` / `TidyBrainFragments` |
| Observe | 开「自主思考」、点地图区域 | Bot 漫游 + 模型独白 + 区域交互 hint | `GetBrainPresence` / `GenerateBrainThought` |
| Inject | 工作台保存策略 / 锁定技能 | preferred + locked skills 进 prompt | `UpdateBrainPolicy` + `rpg.locked_skills` |
| Forget | 遗忘记忆 | 删除 bot 记忆 key | `ForgetBrainMemory` |

## 3. 数值设计

- **XP**：`moe_agent_runtimes.config_json.rpg.total_xp`
- **等级**：`level = 1 + total_xp / 100`，当前环 XP = `total_xp % 100`，下一级需 `100 - 当前环`
- **稳定度**：`stability_score`（试跑奖惩，与 RPG XP 独立）
- **技能槽**：最多 **8** 个 locked tag，存 `rpg.locked_skills`；锁定后注入发帖 prompt（`policy.go` · `【记忆 RPG · 已锁定技能】`）
- **技能等级**：`level = min(5, 1 + count/5)`（tag 频次）

### XP 奖励（管理端动作）

| 动作 | XP |
|------|-----|
| 入梦 · 每条润色成功 | +15 |
| 入梦 · 有合并摘要 | +10 |
| 整理碎片 · 每条认可 | +10 |
| 压缩记忆 | +20 |

## 4. 碎片状态

| status | 条件 |
|--------|------|
| `solid` | approved 且 quality ≥ 70 |
| `fragment` | quality ≥ 50 但未 solid |
| `cracked` | quality < 50 |
| `archived` | memory key 以 `archived:` 开头 |

## 5. 压缩：标记-清扫（算法 + 模型）

纯 LLM 整理容易「润色但不删重复」；压缩采用 **两轮制**，类似人脑 consolidation：

```
第 N 轮                         第 N+1 轮
────────                        ────────
1. 清扫 pending_deletes         1. 清扫上轮标记 …
2. Jaccard 聚类相似 episode    2. 再聚类 …
3. 合并写入 consolidated 记忆  …
4. 标记旧条目 pending（本轮不删）
```

| 概念 | 存储 | 说明 |
|------|------|------|
| `pending_deletes[]` | `config_json.rpg` | `{ kind, ref, marked_at }`，episode 或 memory |
| 聚类 | `compress_algo.go` | bigram Jaccard ≥ 阈值归簇 |
| 合并 | `compress_sweep.go` | 规则拼接 + 可选 LLM 换角度改写（非单纯润色） |
| 清扫 | 同上 | 删除上轮 `pending`，再聚类 |

**CompressBrainMemoriesReply** 字段：`swept_count` · `merged_clusters` · `marked_count` · `pending_remaining` · `source_count` · `xp_gained`

执行压缩 / 整理时，`SetRpgWork(agent, "compressing"|"tidying")` 驱动 presence 与 UI 区域移动。

## 6. 自主思考（Autonomous Mind）

| 项 | 说明 |
|----|------|
| 开关 | `PUT .../brain/rpg/autonomous-mind` → `rpg.autonomous_mind_enabled` |
| 生成 | `POST .../brain/rpg/think` → 模型独白 + 写入 `last_thought` / `thought_history`（最多 6 条，防复读） |
| 展示 | `GET .../brain/presence` → `thought` + `thought_source`（`model` / `rule`） |
| 前端 | 开启后每 ~25s 调用 think；气泡角标区分来源 |
| Prompt | 禁止「背包/碎片/整理/管理台」用语；注入最近发帖片段 + 历史独白 + 随机心绪 |

模型气泡缓存 **3 分钟** 内优先于规则 fallback（`mind.go` · `thoughtForPresence`）。

## 7. API（`api/moe/v1/moe.proto` · MoeAdmin）

| 方法 | HTTP | 说明 |
|------|------|------|
| `GetBrainRpg` | `GET .../runtimes/{agent_key}/brain/rpg` | 等级、技能、碎片、入梦记录、`autonomous_mind_enabled`、`pending_delete_count` |
| `RunBrainDream` | `POST .../brain/rpg/dream` | consolidation + dream log + XP |
| `CompressBrainMemories` | `POST .../brain/rpg/compress` | 标记-清扫压缩（`days` 默认 14） |
| `TidyBrainFragments` | `POST .../brain/rpg/tidy` | Curate 包装 + XP |
| `LockBrainSkill` | `POST .../brain/rpg/skills` | 锁定/解锁 tag（≤8） |
| `ForgetBrainMemory` | `POST .../brain/rpg/forget` | 删除 bot 记忆 key |
| `GetBrainPresence` | `GET .../brain/presence` | activity / mood / thought / thought_source / pipeline / dream |
| `UpdateBrainDreamSchedule` | `PUT .../brain/rpg/dream-schedule` | cron 定时入梦 |
| `UpdateBrainAutonomousMind` | `PUT .../brain/rpg/autonomous-mind` | 自主思考开关 |
| `GenerateBrainThought` | `POST .../brain/rpg/think` | 生成并缓存 Bot 想法 |

契约变更后：`cd backend && make gen`（或 Windows 下对 `api/moe/v1/moe.proto` 跑 protoc），再 `go build ./internal/server/...`。

## 8. `config_json.rpg` 字段

| 字段 | 用途 |
|------|------|
| `total_xp` | RPG 经验 |
| `locked_skills` | 锁定 tag 列表 |
| `last_dream_at` / `dream_enabled` / `dream_cron` / `next_dream_at` | 入梦计划 |
| `autonomous_mind_enabled` | 自主思考 |
| `last_thought` / `last_thought_at` | 最近一次模型/规则气泡 |
| `thought_history` | 最近独白（防复读，≤6） |
| `pending_deletes` | 压缩待删队列 |

## 9. 数据表与配置

| 表 / 配置 | 用途 |
|-----------|------|
| `moe_agent_runtimes.config_json` | 上节 RPG 状态 |
| `moe_brain_dream_logs` | 入梦会话摘要 |
| `moe_bot_episodes` | 碎片来源 |
| `user_memories` | bot 记忆块（RPC） |
| `config.yaml` · `moe.dream_scheduler_enabled` | 进程内定时入梦（默认 true） |
| `config.yaml` · `moe.dream_scheduler_tick_seconds` | 调度 tick（默认 300） |

迁移：`go run ./cmd/migrate -models moe_brain_dream_logs`

## 10. 后端代码地图

| 路径 | 职责 |
|------|------|
| `pkg/moe/brain/rpg.go` | RPG 状态、RunDream、Compress、Tidy、XP |
| `pkg/moe/brain/compress_algo.go` | Jaccard 聚类 |
| `pkg/moe/brain/compress_sweep.go` | 标记-清扫合并 |
| `pkg/moe/brain/mind.go` | 自主思考生成 |
| `pkg/moe/brain/presence.go` | 在场状态合成 |
| `pkg/moe/brain/rpg_work.go` | compressing / tidying 进行中标记 |
| `pkg/moe/brain/dream_schedule.go` · `dream_state.go` · `dream_narrative.go` | 定时入梦 + LLM 叙事 |
| `internal/platform/bootstrap/dream_scheduler.go` | cron 调度循环 |
| `internal/biz/moe/brain_rpg.go` · `brain_presence.go` | biz 入口 |
| `internal/server/transport/brain_pipeline_ws.go` | 试跑流水线 WebSocket |

## 11. 前端结构

| 路径 | 职责 |
|------|------|
| `moe-admin/src/pages/MoeBrainPage.tsx` | AI 大脑页 · Tab 切换 · 试跑（WS 等待） |
| `moe-admin/src/components/BrainRpgPanel.tsx` | RPG 主面板 · 自主思考 · 压缩/入梦操作 |
| `moe-admin/src/components/BrainRpgCharacter.tsx` | 2D 场景 · Bot 移动 · 气泡 |
| `moe-admin/src/components/BrainPipelinePanel.tsx` | 试跑流水线（WS 订阅） |
| `moe-admin/src/lib/brainRpgData.ts` | RPG 数据 normalize |
| `moe-admin/src/lib/brainRpgPresence.ts` | presence normalize + activity 文案 |
| `moe-admin/src/lib/brainRpgWorld.ts` | **开放世界五区域**定义与 activity→zone 映射 |
| `moe-admin/src/lib/moePipelineWs.ts` | 流水线 WS · **断线重连**（避免生成阶段误报失败） |
| `moe-admin/src/styles/components/brain-rpg.css` | 组件样式 |

## 12. 游戏化 UI（当前）

### 12.1 开放世界五区域（`brainRpgWorld.ts`）

| zone id | 名称 | Bot 何时移入 |
|---------|------|--------------|
| `camp` | 营地 | idle |
| `meadow` | 草原 | exploring / walking |
| `memory_shrine` | 记忆神社 | dreaming / tidying / compressing |
| `post_stage` | 发帖台 | posting（试跑流水线） |
| `skill_grove` | 技能树 | exploring 且已有锁定技能 |

- 活动变化时 Bot **先走到区域中心**，再在区域内小范围漫游  
- **点击区域**高亮 + 下方 hint（区域说明与推荐操作）  
- presence 每 **2.5s** 轮询（`GET .../brain/presence`）

### 12.2 activity 枚举

`idle` · `exploring` · `walking` · `posting` · `dreaming` · `tidying` · `compressing`

### 12.3 试跑流水线 WebSocket

- 地址：`/ws/admin/moe/brain/pipeline?agent_key=&admin_token=`（Vite 5173 走同源代理）
- 生成阶段可能 **数分钟**；`waitMoeBrainPipelineWs` 在 `running=true` 时 **自动重连**，仅在 `running=false` 后判定成功/失败 toast  
- 详见 `moePipelineWs.ts` · `MoeBrainPage.runOncePost`

### 12.4 定时入梦

- UI：`BrainRpgPanel` cron 开关 + 保存  
- 后端：`dream_scheduler` 读 `dream_enabled` + `dream_cron`，到点调用 `RunDream`

## 13. 模型无关原则

- **入梦 / 整理**：有 `llm_inference` 时 LLM 润色；无则规则摘要 + 统计，仍写 dream log  
- **压缩**：**必须先算法聚类**再可选 LLM 改写；标记-清扫保证真删重复  
- **自主思考**：无 inference 时规则 fallback（生活化短句，非管理台用语）  
- **图谱 / 工作台**：独立 Tab，RPG 为聚合入口与观察层

## 14. 后续（未做）

- 像素风精灵 / 区域内饰动画（打字、入梦特效）  
- presence **WebSocket** 推送（替代 2.5s 轮询）  
- 试跑时 RPG Tab 订阅 pipeline WS，Bot 在发帖台同步显示当前 phase  
- `GetBrainPipelineReply` proto 补齐 `running` / `generate_attempts`（HTTP GET 与 WS 字段对齐）
