# Agent Session 归档

按 **日期 + 主题** 保存会话复盘，供并行 worktree 或新会话快速对齐。

## 命名

`YYYY-MM-DD-简短主题.md`（英文或拼音均可），例如：

- `2026-05-27-moe-brain-admin-pipeline.md`
- `2026-05-28-memory-embedding-rpc.md`

## 新建

复制 [_TEMPLATE.md](./_TEMPLATE.md)，填完后提交（可与功能 PR 同 PR，或单独 docs PR）。

## 维护

- 稳定结论 → 合并进 `docs/dev/` 或 `docs/product/`，再从 Session 删重复段落。  
- 重复踩坑 → 确认后写入 [.cursor/LESSONS.md](../../../.cursor/LESSONS.md)。  
- 冲刺结束可删 `_CURRENT_SPRINT.md`（若使用，见 [agent-long-term-memory.md](../agent-long-term-memory.md)）。

## 流程说明

见 [agent-long-term-memory.md](../agent-long-term-memory.md)。
