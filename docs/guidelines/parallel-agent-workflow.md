# 多 Agent 并行协作（Playbook）

> **Cursor 规则（自动注入）**：`.cursor/rules/parallel-agent-workflow.mdc`  
> **大任务可选工作流**： [compound-engineering.md](./compound-engineering.md) · `.cursor/rules/compound-engineering.mdc`  
> **迁移状态板**：[kratos-migration-status.md](../dev/kratos-migration-status.md)（Current / Next）

## 与 Kratos 迁移的对应关系

| 迁移阶段 | 状态 | 是否建议并行 |
|----------|------|----------------|
| P0–P6（compat / logic / P6 契约） | ✅ **100%** | — |
| **Next：分体部署** | 见 [kratos-migration-status.md](../dev/kratos-migration-status.md) | 按 `api` / `rpc` / 域拆 worktree |

**大任务并行示例（通用）**

| 子代理 | 分支示例 | 范围 |
|--------|----------|------|
| **U** | `feat/user-*` | `user_compat` / `biz/user` / Flutter `lib/pages` |
| **A** | `feat/admin-*` | `admin_*_compat` / `moe-admin` |
| **P** | `feat/platform-*` | `platform_compat` / LLM 配置 |

**约束**：子代理只改指定域；`register_all.go` / `route_stats.go` 由父会话单点合并。每批：`cd backend && make check`。

---

## 为什么

- **大任务单线程**：上下文膨胀、后半段质量下降、合并前才发现冲突。
- **worktree 优于同目录多分支**：每个 Agent 会话独占目录，避免未保存/错分支/互相覆盖。

## 快速决策

| 场景 | 做法 |
|------|------|
| 改 1～2 个文件、明确 bug | 单 Agent |
| 多域 handler 改线、跨目录大重构 | **拆子任务 + 并行子代理** |
| 两个功能互不依赖 | **两个 worktree + 两个会话** |

## 操作清单（父 Agent / 人类）

1. 列出子任务表（域、文件边界、验收命令、禁止触碰）。
2. 创建 worktree（可选）：`git worktree add ../moe_social-feat-user -b feat/p3-user-handler-biz`
3. 并行启动子代理，每个只拿一张子任务表。
4. 合并分支 → `cd backend && make check` → 更新 [kratos-migration-status.md](../dev/kratos-migration-status.md)。

---

维护：规则以 `.cursor/rules/parallel-agent-workflow.mdc` 为准；迁移数字以 `kratos-migration-status.md` 为准。
