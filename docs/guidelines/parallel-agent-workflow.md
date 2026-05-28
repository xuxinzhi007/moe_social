# 多 Agent 并行协作（Playbook）

> **Cursor 规则（自动注入）**：`.cursor/rules/parallel-agent-workflow.mdc`  
> **迁移状态板**：[kratos-migration-status.md](../dev/kratos-migration-status.md)（Current / Next）  
> **外部参考**：[Claude Code — git worktrees 并行会话](https://code.claude.com/docs/en/common-workflows#run-parallel-claude-code-sessions-with-git-worktrees)

## 与 Kratos 迁移的对应关系

| 迁移阶段 | 状态 | 是否建议并行 |
|----------|------|----------------|
| P1 HTTP compat 注册 | ✅ 完成 | — |
| **P2 直挂 App** | 🔄 ~21%（56/263） | **是**（N1～N4 可拆子代理） |
| P3 删 logic | ⏳ 未开始 | 单域串行即可 |

当前 **Next** 默认并行拆法：

| 子代理 | 分支/worktree 示例 | 范围 |
|--------|-------------------|------|
| A | `feat/admin-app-compat` | `admin_service_compat.go` → `AdminApp`（55） |
| B | `feat/user-app-compat` | `user_compat.go` + `user_memory_compat.go`（57） |
| C | `feat/ai-chat-app-compat` | `ai_compat.go` + `chat_compat` 私信（17） |
| D | `feat/platform-llm-compat` | `platform_compat.go` LLM 写 |

父会话：**最后**改 `register_all.go` · `route_stats.go` · 更新 [kratos-migration-status.md](../dev/kratos-migration-status.md)。

---

## 为什么

- **大任务单线程**：上下文膨胀、后半段质量下降、合并前才发现冲突。
- **worktree 优于同目录多分支**：每个 Agent 会话独占目录，避免未保存/错分支/互相覆盖。

## 快速决策

| 场景 | 做法 |
|------|------|
| 改 1～2 个文件、明确 bug | 单 Agent |
| 多域迁移、多 compat 文件、调研+实现+文档 | **拆子任务 + 并行子代理** |
| 两个功能互不依赖 | **两个 worktree + 两个会话** |

## 操作清单（父 Agent / 人类）

1. 列出子任务表（域、文件边界、验收命令、禁止触碰）。
2. 创建 worktree（可选但推荐）：
   ```bash
   git worktree add ../moe_social-feat-admin -b feat/admin-app-compat
   git worktree add ../moe_social-feat-user  -b feat/user-app-compat
   ```
3. 并行启动子代理（Cursor `Task`），每个只拿一张子任务表。
4. 共享文件（`register_all.go` 等）**最后由一人改**。
5. 合并分支 → `cd backend && make check` → 更新 [kratos-migration-status.md](../dev/kratos-migration-status.md) §0 数字。

## 可选 Cursor 能力（了解即可）

- `/hooks`：长任务进度监控  
- 远程/报告类能力随 Cursor 版本变化，以官方文档为准  

---

维护：规则以 `.cursor/rules/parallel-agent-workflow.mdc` 为准；迁移数字以 `kratos-migration-status.md` 为准。
