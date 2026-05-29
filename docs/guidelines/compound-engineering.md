# Compound Engineering（CE）— 命令与用法

> **插件**：Cursor 市场 `compound-engineering`（本仓库 [`.cursor/settings.json`](../../.cursor/settings.json) 已 `enabled: true`）  
> **Agent 规则**：[`.cursor/rules/compound-engineering.mdc`](../../.cursor/rules/compound-engineering.mdc)（按需加载，AI 自决是否采用）  
> **官方**：[EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)

## 理念（与本仓库对齐）

**Plan → Work → Review → Compound → Repeat** — 每轮工作应让下一轮更容易。

| CE 步骤 | 本仓库等价物 |
|---------|----------------|
| Plan | `docs/dev/*` SSOT · [kratos-migration-status.md](../dev/kratos-migration-status.md) · 契约先冻结 |
| Work | `make check` · 域边界 · [parallel-agent-workflow.md](./parallel-agent-workflow.md) |
| Review | `code_review.md` · `/review` · `code-reviewer-agent` |
| Compound | [sessions/_TEMPLATE.md](./sessions/_TEMPLATE.md) · 稳定事实进 L2 · [.cursor/LESSONS.md](../../.cursor/LESSONS.md) |

CE **不替代** `.cursor/rules/*-ai-spec.mdc` 与 `LESSONS`；负责结构化「大任务怎么开、怎么收」。

---

## 安装与配置

### 安装（Cursor Agent 聊天）

```text
/add-plugin compound-engineering
```

或在插件市场搜索 `compound engineering`。

### 项目引导

```text
/ce-setup
```

检查环境并初始化项目配置。

### 本地配置（可选）

```bash
cp .compound-engineering/config.local.example.yaml .compound-engineering/config.local.yaml
```

| 配置项 | 用途 |
|--------|------|
| `work_delegate: codex` | 将执行委托给 Codex CLI |
| `work_delegate_consent` / `work_delegate_model` | 委托开关与模型 |
| `pulse_*` | `/ce-product-pulse` 数据源（PostHog、Sentry 等） |
| `plan_output` / `brainstorm_output` | `md` 或 `html` |

`config.local.yaml` 已在 `.gitignore`，勿提交密钥。

---

## 命令速查

在 Cursor Agent 输入 `/` 搜索 `ce-` 前缀。

### 策略与创意（上游）

| 命令 | 用途 | 典型产出 |
|------|------|----------|
| `/ce-strategy` | 产品方向锚点 | `STRATEGY.md` |
| `/ce-ideate` | 大范围创意与排序 | 排名后的 ideation 文档 |
| `/ce-brainstorm` | 交互式澄清需求 | `docs/brainstorms/*-requirements.md` |

### 核心循环

| 命令 | 用途 | 典型产出 |
|------|------|----------|
| `/ce-plan` | 需求 → 实现计划 | `docs/plans/*.md` |
| `/ce-work` | 按计划执行（worktree、任务） | 分支 + PR |
| `/ce-code-review` | 多维度审查 | review findings |
| `/ce-compound` | **沉淀经验**（最重要） | `docs/solutions/*.md` |
| `/ce-debug` | 系统化排障 | 根因 + 修复 |

### 观测与维护

| 命令 | 用途 |
|------|------|
| `/ce-product-pulse` | 时间窗口产品脉冲（用法、错误、转化） |
| `/ce-product-pulse setup` | 首次配置 `pulse_*` |
| `/ce-doc-review` | 文档审查 |

---

## 推荐工作流

### 新功能（跨栈 / ≥5 文件）

```text
/ce-brainstorm "功能简述与约束"
/ce-plan docs/brainstorms/xxx-requirements.md
/ce-work
/ce-code-review
/ce-compound
```

**本仓库注意**：Flutter / backend / moe-admin 契约联动时，先冻结 `api/*/v1/*.proto`，再并行 UI（见 [parallel-agent-workflow.md](./parallel-agent-workflow.md)）。

### 修 Bug（单域、步骤明确）

Agent 通常 **不必** 走全套 CE；直接修 + `make check` / `flutter analyze`。复杂根因可用：

```text
/ce-debug "复现步骤与现象"
/ce-compound
```

### 文档 / 瘦身 / 索引对齐

```text
/ce-brainstorm "文档合并范围与 SSOT"
/ce-plan docs/brainstorms/xxx-requirements.md
```

执行可由当前 Agent 完成，收尾用 Session 摘要（不必强行 `/ce-work`）。

### 合并前审查

```text
/ce-code-review
```

或仓库内 `/review` + `code_review.md`（二选一，避免重复审两遍）。

---

## 产出目录约定（CE × Moe Social）

| CE 默认路径 | 本仓库建议 |
|-------------|------------|
| `docs/brainstorms/` | 可保留；大方案稳定后合并进 `docs/dev/` 或 `docs/product/` |
| `docs/plans/` | 冲刺计划；结束归档到 `docs/guidelines/sessions/` |
| `docs/solutions/` | 可检索解法；与 Session 不重复时保留 |
| `STRATEGY.md` | 产品级；与 [product/项目开发总览](../product/项目开发总览与当前优先级-2026-05-18.md) 对齐 |
| `docs/pulse-reports/` | 运营脉冲；与产品指标文档互链 |

**Compound 收尾**：优先 [sessions/_TEMPLATE.md](./sessions/_TEMPLATE.md)；重复踩坑 **提议** 写入 `.cursor/LESSONS.md`（人确认后再改）。

---

## Agent 自决：何时用 / 何时不用

### 建议采用 CE 流程

- 需求模糊、多方案权衡、≥5 文件或 ≥2 目录
- 跨 `lib/` + `backend/` + `moe-admin/` 联动
- 合并前需要系统化 review
- 本轮有可复用架构/流程教训

### 不必走 CE

- 单文件 bug、纯问答、用户已给完整步骤
- 仅改文档链接/错别字
- 紧急热修（先修后补 compound）

### Agent 无 `/ce-*` 时

在 Cursor Agent 内无法代用户输入斜杠命令时，**按同一四步执行**，并在回复中说明「已按 CE 流程」；可建议用户在**新会话**中运行 `/ce-plan` 等以复用插件子 agent。

---

## 与现有工具对照

| 场景 | CE | 本仓库原生 |
|------|-----|------------|
| 大任务拆分 | `/ce-work` | `Task` 子代理 + [parallel-agent-workflow.mdc](../../.cursor/rules/parallel-agent-workflow.mdc) |
| 代码审查 | `/ce-code-review` | `/review` · `code-reviewer-agent` |
| 会话沉淀 | `/ce-compound` | Session 摘要 · `docs/guidelines/sessions/` |
| 重复踩坑 | compound 文档 | `.cursor/LESSONS.md` |
| 后端验收 | — | `cd backend && make check` |
| Flutter 验收 | — | `flutter analyze` · `flutter test` |

---

## 故障排查

| 现象 | 处理 |
|------|------|
| 输入 `/` 无 `ce-` 命令 | 运行 `/add-plugin compound-engineering` 或检查 settings 插件开关 |
| 委托 Codex 失败 | 配置 `.compound-engineering/config.local.yaml` 的 `work_delegate_*` |
| 与仓库规范冲突 | **以** `*-ai-spec.mdc` **与** SSOT **为准**，CE 产出需符合 Moe 目录约定 |

---

最后更新：**2026-05-29**
