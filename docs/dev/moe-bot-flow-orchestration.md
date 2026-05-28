# Moe Bot 可视化编排 — 产品决策与实现路线

> 状态：**E0 + E1 已落地**（2026-05-28）；E2+ 分支/失败策略见 §9  
> 关联：`moe_agent_flow_configs`、`pkg/moe/runtime/RunOnce`、`moe_tool_calls`、管理台 Bot 编排画布

## 1. 产品决策（SSOT）

| 问题 | 决策 |
|------|------|
| 画布连线是否改变执行顺序/分支？ | **可以** — 连线定义可执行 DAG，而非纯展示 |
| 工具节点定位？ | **既要**展示 registry 支持的能力，**又要**作为可执行节点 |
| 失败策略？ | **支持** skip / retry / manual（人工介入） |
| 与 RunOnce、cron、brain 策略优先级？ | **同级别** — 同一套编排入口，策略在运行前注入上下文 |

### 1.1 非目标（避免 scope 爆炸）

- 不替代 App 侧 LLM Chat 的 tool loop（仍走对话链路）。
- 不在 v1 引擎支持任意 Turing 完备脚本；条件边先限定为 `on_ok` / `on_fail` / 简单表达式。
- 管理台画布仍负责编辑；执行在 `backend/pkg/moe/flowexec`（拟议包名）。

## 2. 统一执行入口（与 cron / 试跑同级）

今天所有发帖回合都硬编码在 `runtime.RunOnce`；调度器 `scheduler.go` 直接调用它。

```
                    ┌─────────────────┐
  管理台试跑 ───────►│                 │
  cron / smart ─────►│  RunAgent()     │──► flowexec.Engine
  未来 Webhook ─────►│  (统一入口)      │         │
                    └────────┬────────┘         ▼
                             │            DAG + 失败策略
         brain 策略 ─────────┼────────► Context.Policy
         runtime 配置 ───────┘
         flow layout_json ─────────────► CompiledGraph
```

**规则**：`RunOnce` 退化为「加载默认图并调用 `RunAgent`」的薄封装，避免双实现。

```go
// 拟议签名（internal/biz/moe 或 pkg/moe/runtime）
func RunAgent(ctx context.Context, deps Deps, agentKey string, trigger RunTrigger) (RunOnceResult, error)
```

`RunTrigger`：`manual` | `cron` | `smart` | `admin_test` — 仅影响审计字段与是否允许 `manual` 暂停恢复。

## 3. 配置模型：layout_json v2

在现有 `nodes` / `edges` / `viewport` 上增加 **`version: 2`** 与执行语义字段（可渐进迁移：无 version 时按 v1 仅展示，v2 才参与执行）。

### 3.1 节点（Node）

| 字段 | 说明 |
|------|------|
| `id` | 稳定 ID |
| `type` | `core` \| `step` \| `tool` |
| `kind` | 执行器类型（见下表） |
| `tool_name` | `type=tool` 时必填，须在 registry |
| `enabled` | false 时编译跳过（灰显） |
| `on_fail` | `skip` \| `retry` \| `abort` \| `manual` |
| `retry` | `{ "max": 3, "backoff_ms": 1000 }`，仅 `retry` 时有效 |
| `label` / `subtitle` / `position_*` | UI |

**kind 与当前 RunOnce 映射（P1 内置）**

| kind | 对应今日逻辑 |
|------|----------------|
| `load_runtime` | 加载 `MoeAgentRuntime` |
| `gather_memory` | 记忆脉搏 / 近期帖统计 |
| `llm_generate` | `generatePostContent` 全流程 |
| `generate_finalize` | 质检汇总（可与 llm 合并为一个复合节点，P1 可内嵌） |
| `tool` | `tools.Executor.Execute` |
| `record_episode` | `brain.RecordEpisode` |

P2 增加：`branch`（仅根据上步 ok/fail 选边，不执行代码）。

### 3.2 边（Edge）

| 字段 | 说明 |
|------|------|
| `source` / `target` | 节点 ID |
| `kind` | `default` \| `on_ok` \| `on_fail` |
| `label` | UI 可选 |

**分支规则**：某节点完成后，只沿 `on_ok` 或 `on_fail` 且与结果匹配的边继续；无匹配边则 `on_fail` 视为 abort。`default` 用于无分支的线性链。

### 3.3 图级

| 字段 | 说明 |
|------|------|
| `entry_node_id` | 入口，默认 `core` 的子节点或 `load` |
| `version` | `2` 表示可执行 |

保存时 **编译校验**（biz 层）：

- 无环（DAG）
- 从 `entry` 可达所有 `enabled` 节点
- `tool_name` ∈ registry 且 tier 允许
- 发帖主路径至少包含 `llm_generate` + `post_create`（可配置策略名 `posting_minimal_path`）

## 4. 执行引擎（flowexec）

建议新包：`backend/pkg/moe/flowexec/`

```
flowexec/
  compile.go      # layout → CompiledGraph
  engine.go       # Run(ctx, graph, execCtx)
  context.go      # 运行态：rt, policy, vars, last_ok
  handlers.go     # 各 kind 的 Handler 注册表
  failure.go      # skip / retry / abort / manual
  manual.go       # 暂停快照读写
```

### 4.1 运行上下文 `ExecContext`

- `Runtime`：`MoeAgentRuntime`
- `BrainPolicy`：`forbidden_tags` / `preferred_tags`（与 brain 同级别注入）
- `Vars`：`map[string]any`（如 `post_id`, `content`, `gen_attempts`）
- `Recorder`：现有 `StepRecorder` → `moe_agent_run_logs`
- `Trigger`：`RunTrigger`

### 4.2 执行循环（简述）

1. 编译图，得到拓扑序 + 邻接（按边 kind 分组）。
2. 从 `entry` 开始 BFS/按序执行：
   - `enabled=false` → skip
   - 调用 `handlers[kind]`
   - 失败 → 按节点 `on_fail`：
     - **skip**：记 step skip，走 `on_fail` 边或继续下游（若无边则 abort）
     - **retry**：同节点重试至 `retry.max`
     - **abort**：结束 run，`saveLog(false, ...)`
     - **manual**：写入 `moe_agent_flow_run` 状态 `paused`，返回管理台可恢复
3. 成功 → 沿 `on_ok` 或 `default` 边继续。

### 4.3 与 brain 策略「同级别」

在 `RunAgent` 开头一次加载：

```text
snap := brain.LoadSnapshot(db, rpc, agentKey)
execCtx.Policy = snap.PolicyFields()
```

`llm_generate` handler 内继续使用现有 `generatePostContent` / topic / stability，**不**把 brain 降级为「仅展示」。

### 4.4 与 cron「同级别」

`scheduler.go` 改为：

```go
result, runErr := RunAgent(ctx, deps, rt.AgentKey, TriggerCron)
```

smart 模式同理。

## 5. 能力展示 vs 可执行

| 层级 | 数据来源 | UI |
|------|----------|-----|
| 平台能力 | `tools/registry` + tier | 工具面板「可添加」列表 |
| 画布声明 | flow 节点 `tool` + `enabled` | 节点样式 |
| 实际执行 | `flowexec` + `moe_tool_calls` | 试跑高亮 + 审计页 |

**约束**：画布上 `enabled` 且落在 DAG 路径上的 `tool` 才会执行；仅连线但未连入主路径的节点不执行（或标为 orphan 警告）。

## 6. 失败策略语义（实现约定）

| on_fail | 行为 | 管理台 |
|---------|------|--------|
| `skip` | 记录 skip，尝试 `on_fail` 出边 | 节点灰 + skip |
| `retry` | 同节点重试，间隔 `backoff_ms` | 显示重试次数 |
| `abort` | 立即结束本次 run | 失败态 |
| `manual` | 持久化 `PausedRun`，等待恢复 | 「待人工」+ 恢复按钮 |

**人工恢复（P3）**：`POST .../runtimes/:agent_key/flow/runs/:run_id/resume`，从暂停节点继续。

## 7. 数据表（拟新增）

| 表 | 用途 |
|----|------|
| `moe_agent_flow_configs` | 已有，存 layout_json v2 |
| `moe_agent_flow_runs`（新） | 每次执行实例：agent_key, status, paused_node_id, context_json, started_at, finished_at |
| `moe_agent_run_logs` | 已有，步骤明细不变 |

## 8. API 增量（管理台）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `.../flow` | 已有；返回 `version`、编译警告 `warnings[]` |
| PUT | `.../flow` | 已有；保存前服务端 compile 校验 |
| DELETE | `.../flow` | 重置默认（下轮小 PR） |
| POST | `.../run-once` | 内部改调 `RunAgent(..., admin_test)` |
| GET | `.../flow/runs/:id` | 暂停/恢复态查询（P3） |
| POST | `.../flow/runs/:id/resume` | 人工恢复（P3） |

Pipeline 接口增加：`current_run_id`、`node_states[]`（与画布节点 id 对齐）、`tools_invoked[]`。

## 9. 分阶段交付（推荐）

| 阶段 | 交付 | 状态 |
|------|------|------|
| **E0** | `DELETE .../flow`；`pipeline.tools_invoked`；工具节点审计高亮 | **已完成** |
| **E1** | `pkg/moe/flowexec` 编译线性图；`RunAgent`/`RunAgentForAgent`；cron+试跑走画布；保存时 compile 校验 | **已完成** |
| **E2**（3–4d） | `on_ok`/`on_fail` 边 + retry/skip/abort | 中 |
| **E3**（3d） | `manual` + `flow_runs` + 恢复 API + 管理台按钮 | 中高 |
| **E4**（按需） | 画布可插入任意 registry tool 进主路径；条件边表达式 | 高 |

**不要跳级**：未完成 E1 前不要在生产打开「任意 DAG 改发帖顺序」。

## 10. 默认发帖图（E1 应用）

与当前 `DefaultFlowConfig` 等价，但边带 `kind`：

```text
core → load → gather → prep → llm → qc → post → episode
                              ↘ tool:post_create (on_ok 从 qc，可选并行，P2)
```

`llm_generate` 节点 `on_fail: retry`（max=3），`post_create` `on_fail: abort`，`record_episode` `on_fail: skip`。

## 11. 前端演进

| 阶段 | UI |
|------|-----|
| 现 v2 | React Flow 编辑 + 服务端保存 |
| E1 | 节点面板：kind、on_fail、retry、enabled；保存显示 compile warnings |
| E2 | 边类型选择（default / on_ok / on_fail） |
| E3 | 暂停 run 横幅 + 恢复 |
| 能力 | 工具列表 = registry；不可执行 tier 标红 |

## 12. 验收（E1 完成定义）

- [ ] cron 与试跑均走 `RunAgent`，日志 trigger 可区分  
- [ ] 修改画布主路径顺序（如 prep 在 gather 前）后，**步骤顺序与 run_log 一致**  
- [ ] 禁用节点 `enabled:false` 不执行且 run_log 为 skip  
- [ ] brain forbidden_tags 仍影响生成结果  
- [ ] 非法图（环、未知 tool）保存返回 4xx + warnings，不写入 DB  

---

**变更记录**

- 2026-05-28：根据产品确认「可改变执行 / 工具可执行 / 失败策略 / 与 RunOnce·cron·brain 同级」撰写初版。
