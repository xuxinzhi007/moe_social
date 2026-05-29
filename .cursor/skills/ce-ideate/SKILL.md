---
name: ce-ideate
description: >-
  Analyzes Moe Social frontend for hidden UI/UX issues (design consistency,
  interaction patterns, loading/error states, navigation). Produces ranked
  optimization recommendations. Use when the user runs /ce-ideate or asks to
  ideate, audit, or improve Flutter/moe-admin frontend UI and interactions.
disable-model-invocation: true
---

# /ce-ideate — 前端创意与问题发现

Compound Engineering **上游**步骤：在 `/ce-brainstorm` 或 `/ce-plan` 之前，系统性扫描前端隐藏问题并产出可排序的优化清单。

## 核心任务（用户原文）

帮我分析一下当前的项目 前端存在的隐藏问题 ，分析 包括 ui的设计 和交互 ，给出优化的建议

## 范围

| 默认 | 可选 |
|------|------|
| Flutter `lib/`（pages · widgets · app 路由） | `moe-admin/`（用户点名或全栈审计时） |

**只读分析**：本技能默认不改代码。用户选定项后再走 `/ce-plan` → `/ce-work`。

## 启动前必读

1. [.cursorrules](../../../.cursorrules) — Moe UI 设计语言（色板、圆角、阴影、动效）
2. [.cursor/rules/frontend-ai-spec.mdc](../../rules/frontend-ai-spec.mdc)
3. [docs/guidelines/Codex启动指南-前端.md](../../../docs/guidelines/Codex启动指南-前端.md)
4. 若涉及管理台：[moe-admin/docs/admin-design-system.md](../../../moe-admin/docs/admin-design-system.md)

## 工作流

```
Task Progress:
- [ ] 1. 确认范围（Flutter / moe-admin / 指定域）
- [ ] 2. 扫描结构与热点（路由、Tab、高频页面）
- [ ] 3. 按维度审计（见 checklist.md）
- [ ] 4. 跑静态检查（flutter analyze；moe-admin 则 npm run build 仅报障）
- [ ] 5. 产出排名后的 ideation 文档
- [ ] 6. 提示下一步：/ce-brainstorm 或 /ce-plan
```

### 1. 扫描结构

优先阅读（按用户关注点裁剪）：

- `lib/app/app_routes.dart`、`lib/app/main_shell.dart`
- `lib/pages/<domain>/` 与对应 `lib/widgets/`
- 共享组件：`MoeMenuCard`、`FadeInUp`、`NetworkAvatarImage`、按钮/输入封装
- `lib/services/` 与页面的加载/错误处理模式

用 `Grep` / `Glob` 找反模式：`ListTile` 作主菜单、`BorderRadius.zero`、`!` 运算符、缺少 `mounted` 的 async `setState`、页面内裸 HTTP。

### 2. 审计维度

完整清单见 [checklist.md](checklist.md)。摘要：

| 维度 | 关注点 |
|------|--------|
| **设计系统** | 色板/渐变/背景是否偏离 `.cursorrules`；圆角 20–24；柔和阴影；Rounded 图标 |
| **组件复用** | 重复 UI、未用 `MoeMenuCard`/`FadeInUp`、风格割裂 |
| **交互** | 点击反馈（InkWell + 圆角裁剪）、空态/加载态/失败态、表单校验反馈 |
| **导航** | Tab 与深链一致性、返回栈、deferred 路由首屏体验 |
| **性能感知** | 首屏、列表滚动、大图/动效卡顿、Web 特例（Rive 等） |
| **一致性** | 同域页面间距/字号/卡片结构是否统一 |
| **可访问性** | 对比度、触控目标、语义/读屏（基础） |

### 3. 证据要求

每条发现尽量附带：

- **位置**：`lib/pages/...` 或 `lib/widgets/...`（文件 + 行号或组件名）
- **现象**：用户可见的问题
- **影响**：体验/一致性/可维护性/风险
- **建议**：可执行、对齐 Moe 设计语言

无代码证据的猜测标为 **待验证**，不要写成确定结论。

### 4. 排名规则

按 **影响 × 修复成本** 排序：

- **P0** — 明显违背设计规范、交互断链、易崩溃/空指针风险
- **P1** — 多页面不一致、关键路径体验差
- **P2** — 局部 polish、动效、次要页面

## 产出模板

写入 `docs/ideation/YYYY-MM-DD-frontend-ux.md`（目录不存在则创建）：

```markdown
# Frontend UX Ideation — [日期]

## 范围
- 目录：lib/ | moe-admin/
- 重点域：[auth / feed / profile / …]

## 摘要
[3–5 句：最严重问题与整体健康度]

## 发现（按优先级）

### P0
| # | 问题 | 位置 | 建议 | 工作量 |
|---|------|------|------|--------|

### P1
…

### P2
…

## 设计系统符合度
- ✅ 做得好的模式（可推广）
- ❌ 反复出现的偏离

## 建议的下一轮 CE
1. `/ce-brainstorm` — [若需澄清产品/交互方案]
2. `/ce-plan` — [若 P0/P1 项已明确可实施]
```

## 与 CE 流水线衔接

```text
/ce-ideate                    ← 本技能：发现问题、排序
/ce-brainstorm "选定优化主题"  ← 需产品/交互澄清时
/ce-plan docs/ideation/....md  ← 冻结实现计划
/ce-work                       ← 执行
```

## 禁止

- 未读规范就泛泛谈 Material/iOS 默认风格
- 把后端/API 问题混入前端 ideation（可单列「契约阻塞 UI」附录）
- 单次 ideation 覆盖全 90+ 页面 — 按域分批或用户指定范围

## 附加资源

- 详细审计清单：[checklist.md](checklist.md)
