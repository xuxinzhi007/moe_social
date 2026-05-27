# Moe Social 文档中心

> **原则**：只维护少量「当前有效」文档；过时方案迁入 [`archive/`](./archive/)，原路径保留短跳转 stub。  
> **本地预览**：`cd docs && python3 -m http.server 8765` → [index.html](./index.html) · 或 `make dev-docs`（:19012）

## 快速入口

| 我想… | 去看 |
|--------|------|
| 推理服务 + 记忆怎么配合 | [dev/llm-inference-and-memory-vision.md](./dev/llm-inference-and-memory-vision.md) |
| 记忆系统架构 / API | [dev/用户记忆系统-OpenClaw式演进设计.md](./dev/用户记忆系统-OpenClaw式演进设计.md) |
| 验收记忆 / 混合检索 | [dev/用户级记忆统一改造验收脚本.md](./dev/用户级记忆统一改造验收脚本.md) · [memory-system-dashboard.html](./dev/memory-system-dashboard.html) |
| 本地跑起来 | [dev/环境配置说明.md](./dev/环境配置说明.md) · [dev/快速调试步骤.md](./dev/快速调试步骤.md) · [dev/ports.md](./dev/ports.md) |
| 管理台（React） | [../moe-admin/README.md](../moe-admin/README.md) · [dev/moe-admin.md](./dev/moe-admin.md) |
| 产品优先级与 AI 酒馆 | [product/项目开发总览与当前优先级-2026-05-18.md](./product/项目开发总览与当前优先级-2026-05-18.md) · [product/AI酒馆化改造方案.md](./product/AI酒馆化改造方案.md) |
| 开发规范 | [guidelines/Codex启动指南-后端.md](./guidelines/Codex启动指南-后端.md) · [guidelines/Codex启动指南-前端.md](./guidelines/Codex启动指南-前端.md) · [../code_review.md](../code_review.md) |
| Agent 长期记忆 / Session 复盘 | [guidelines/agent-long-term-memory.md](./guidelines/agent-long-term-memory.md) · [.cursor/LESSONS.md](../.cursor/LESSONS.md) · [guidelines/sessions/](./guidelines/sessions/) |
| 历史 / 过时文档 | [archive/README.md](./archive/README.md) |

---

## 目录结构

```
docs/
├── README.md          ← 本文件（总索引）
├── index.html         ← 浏览器导航
├── archive/           ← 已归档，勿作主维护
├── dev/               ← 开发、联调、推理/记忆 SSOT
├── product/           ← 产品方案与 UI
├── planning/          ← 待实施规划
├── features/          ← 功能说明
├── guidelines/        ← 规范与 Codex 指南
├── autoglm/           ← AutoGLM 子系统
├── testing/           ← 测试清单
└── specs/             ← 专项需求规格
```

各子目录均有 `README.md` 索引（`dev/`、`product/`、`archive/` 等）。

---

## 推理与记忆（精简）

| 优先级 | 文档 | 说明 |
|--------|------|------|
| 1 | [llm-inference-and-memory-vision.md](./dev/llm-inference-and-memory-vision.md) | **推理 + 记忆产品/配置 SSOT**（llama-server、`llm_inference.*`） |
| 2 | [用户记忆系统-OpenClaw式演进设计.md](./dev/用户记忆系统-OpenClaw式演进设计.md) | 记忆库架构、API、路径 A/B |
| 3 | [记忆系统-2026-05-20-变更整理.md](./dev/记忆系统-2026-05-20-变更整理.md) | 近期变更与验收（增量） |
| 4 | [memory/README.md](./dev/memory/README.md) | 代码目录地图 |

~~Ollama 记忆三文档~~ → 已归档至 [archive/memory/](./archive/memory/)（`docs/dev/ollama*` 为跳转 stub）

---

## 开发与联调

详见 [dev/README.md](./dev/README.md)。

常用：环境、快速调试、API 调试、打包、飞书 OAuth、私信流程、安全 backlog、Moe Admin。

---

## 产品与设计

详见 [product/README.md](./product/README.md)。

主入口：**项目开发总览**、**AI 酒馆化改造方案**；带日期的 `*-2026-05-*.md` 为方案快照。

---

## 其他子系统

| 目录 | 入口 |
|------|------|
| AutoGLM | [autoglm/AutoGLM_README.md](./autoglm/AutoGLM_README.md) |
| 功能指南 | [features/NEW_FEATURES_GUIDE.md](./features/NEW_FEATURES_GUIDE.md) |
| 测试 | [testing/E2E测试清单.md](./testing/E2E测试清单.md) |
| 后端私信 | [../backend/docs/private_messages.md](../backend/docs/private_messages.md) |
| 开发者工具台 | [dev/devtools.html](dev/devtools.html) |
| RPC 监控 | [dev/tools/rpc-monitor.html](dev/tools/rpc-monitor.html) |

---

## 仓库根目录与 backend 散落文档

| 位置 | 说明 |
|------|------|
| `code_review.md` | Code review 标准 |
| `backend/README.md` | 后端启动与 `make gen` |
| `backend/架构说明.md` | 当前 API→RPC→DB 分层（精简） |
| `backend/待完成事项.md` | 后端待办 |
| [archive/root/](./archive/root/) | 已从根目录迁入的一次性分析（扫雷、扫码、成就等） |
| [archive/backend/](./archive/backend/) | 已从 `backend/` 迁入的历史状态文档 |

新文档请优先放入 `docs/<category>/`，避免在仓库根目录堆积。

---

## 文档维护约定

1. **一个主题一份 SSOT**，其余只写增量或归档。  
2. **方案落地后**：更新 SSOT 变更记录，将旧方案移入 `archive/` 并留 stub。  
3. **文件名带日期**表示快照，须在 `product/README` 或文首注明是否仍有效。  
4. **推理、记忆、设备、AI Provider** 禁止再开并行架构文档。

---

最后整理：**2026-05-27**
