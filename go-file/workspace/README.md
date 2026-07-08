# AI 工作区

此目录供 Grok 等 AI 通过 MCP 自由读写，与服务代码隔离。

## 目录说明

| 目录 | 用途 |
|------|------|
| collab/ | 协同任务与状态 |
| collab/plans/ | 方案文档 |
| collab/decisions/ | 已确定决策 |
| notes/ | 临时笔记 |
| tests/ | 接口测试 JSON |
| scratch/ | 草稿与实验 |

## 开始协作

1. 读取 collab/active-task.json
2. 方案写入 collab/plans/
3. 完成后更新 active-task.json 的 phase 字段
