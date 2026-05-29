# Agent 长期记忆（复利工程）

> 让 Cursor/Codex 等 Agent **跨会话变聪明**，而不是每次从零读仓库。  
> 原则：**入口短、专题深、踩坑才进 LESSONS、会话结束要沉淀**。

## 1. 记忆分层

```text
┌─────────────────────────────────────────────────────────┐
│ L0 始终加载（<100 行/文件）                              │
│  AGENTS.md · .cursorrules · ai-startup-enforcer.mdc     │
└───────────────────────────┬─────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│ L1 按任务层加载                                          │
│  backend / frontend / moe-admin 的 *-ai-spec.mdc        │
│  Codex启动指南-后端.md · Codex启动指南-前端.md           │
│  .cursor/LESSONS.md  ← 累计教训（必读）                  │
└───────────────────────────┬─────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│ L2 专题 SSOT（按需读，可很长）                           │
│  docs/dev/* · docs/product/* · backend/README.md       │
└───────────────────────────┬─────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│ L3 会话沉淀（按日期/主题归档）                           │
│  docs/guidelines/sessions/YYYY-MM-DD-主题.md              │
└─────────────────────────────────────────────────────────┘
```

| 层级 | 写什么 | 不写什么 |
|------|--------|----------|
| L0 | 结构、命令、done 标准、链接 | 记忆架构、UI 色值全文 |
| L1 | 分层边界、生成命令、重复踩坑 | 一次性调试笔记 |
| L2 | 架构、验收脚本、产品方案 | 已归档的 Ollama 旧方案 |
| L3 | 本轮结论、未合并决策、下轮任务 | 可合并进 L2 的稳定设计 |

## 2. 文件职责

| 文件 | 角色 |
|------|------|
| [AGENTS.md](../../AGENTS.md) | 仓库入口；链接本体系 |
| [.cursor/LESSONS.md](../../.cursor/LESSONS.md) | **唯一**「重复踩坑」清单 |
| [.cursor/rules/agent-memory.mdc](../../.cursor/rules/agent-memory.mdc) | 启动读 LESSONS、结束输出 Session 摘要 |
| [.cursor/rules/compound-engineering.mdc](../../.cursor/rules/compound-engineering.mdc) | CE 大任务工作流（Agent 按需自决） |
| [compound-engineering.md](./compound-engineering.md) | CE 斜杠命令与产出目录 |
| [sessions/_TEMPLATE.md](./sessions/_TEMPLATE.md) | Session 复盘模板 |
| [sessions/](./sessions/) | 按主题归档的历史会话 |

## 3. 何时写入 LESSONS

满足 **任一** 即可新增一条（保持 ≤3 行）：

1. 同类错误在 **不同会话** 出现 ≥2 次；或  
2. 一次错误导致 **契约破坏 / 大范围回滚 / 生产风险**。

**不要** 写入：一次性的环境路径、未验证猜测、已在 L2 SSOT 写清的完整流程（LESSONS 只留指针）。

写入后同步检查：L2 文档是否也应更新（设计已稳定时）。

## 4. Session 结束流程（Agent）

当本轮有 **实质代码或契约改动** 时，在收尾回复中附带 Session 摘要（可复制到 `docs/guidelines/sessions/`）：

1. 使用 [sessions/_TEMPLATE.md](./sessions/_TEMPLATE.md) 填写。  
2. 「可复用知识」≤5 条；稳定结论 **合并进 L2**，不要只在 Session 里留一份。  
3. 提议写入 LESSONS 的条目须标注 **「建议 LESSONS #N」**，由人确认后再改 `.cursor/LESSONS.md`。  
4. 列出 **下轮 1 主任务 + 最多 2 卫星任务**（review / 文档 / 单栈 UI）。

人类也可在合并 PR 前自行粘贴 Session 文件，便于并行 worktree 对齐。

## 5. 模型升级时的压缩

换更强模型或上下文变紧时：

1. 只保留 L0 + `.cursor/LESSONS.md` + 当前迭代的 L2 SSOT（见 LESSONS 内表格）。  
2. 将 `docs/guidelines/sessions/` 中 **最近 3 份** Session 合并为一段「当前冲刺状态」，写入 `sessions/_CURRENT_SPRINT.md`（可选，冲刺结束删除）。  
3. 删除 Session 里已与 L2 重复的段落，避免三处维护同一设计。

## 6. 与并行 Agent 的配合

- **契约互斥**：同一时刻只允许一个 worktree/会话改 `super.api` + `super.proto`。  
- **子代理边界**：见 `.cursor/agents/*.md`；派工说明写进 Session 的「下轮任务」。  
- **审查卫星**：未合并 diff 交给 `code-reviewer-agent` 或 `/review`，不占用主会话改代码。

## 7. 快速检查清单

**开始任务前**

- [ ] 已判断 Flutter / backend / moe-admin / 联动  
- [ ] 已读对应 `*-ai-spec.mdc` 与启动指南  
- [ ] 已读 `.cursor/LESSONS.md`  

**结束任务前**

- [ ] 检查已跑并报告  
- [ ] 已输出 Session 摘要（或说明为何跳过）  
- [ ] 重复踩坑已提议写入 LESSONS（未自动写入）
