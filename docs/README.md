# Moe Social 文档中心

> **原则**：只维护「当前有效」文档；过时内容直接删除，不保留 `archive/` 跳转 stub。  
> **本地预览**：`cd docs && python3 -m http.server 8765` → [index.html](./index.html) · 或 `make dev-docs`（:19012）

## 快速入口

| 我想… | 去看 |
|--------|------|
| 推理服务 + 记忆怎么配合 | [dev/llm-inference-and-memory-vision.md](./dev/llm-inference-and-memory-vision.md) |
| 记忆 RPG / Bot 观察 UI | [dev/moe-brain-memory-rpg.md](./dev/moe-brain-memory-rpg.md) |
| 记忆系统架构 / API | [dev/用户记忆系统-OpenClaw式演进设计.md](./dev/用户记忆系统-OpenClaw式演进设计.md) |
| 验收记忆 / 混合检索 | [dev/用户级记忆统一改造验收脚本.md](./dev/用户级记忆统一改造验收脚本.md) · [memory-system-dashboard.html](./dev/memory-system-dashboard.html) |
| 本地跑起来 | [dev/环境配置说明.md](./dev/环境配置说明.md) · [dev/快速调试步骤.md](./dev/快速调试步骤.md) · [dev/ports.md](./dev/ports.md) |
| **OpenAPI / Apifox 同步** | [dev/openapi-apifox.md](./dev/openapi-apifox.md) |
| 管理台（React） | [../moe-admin/README.md](../moe-admin/README.md) · [dev/moe-admin.md](./dev/moe-admin.md) |
| 产品优先级与 AI 酒馆 | [product/项目开发总览与当前优先级-2026-05-18.md](./product/项目开发总览与当前优先级-2026-05-18.md) · [product/AI酒馆化改造方案.md](./product/AI酒馆化改造方案.md) |
| 开发规范 | [../AGENTS.md](../AGENTS.md) · [.cursor/rules/moe-social-unified.mdc](../.cursor/rules/moe-social-unified.mdc) · [../code_review.md](../code_review.md) |
| **Kratos 后端** | [dev/kratos-migration-status.md](./dev/kratos-migration-status.md) · [dev/kratos-architecture-audit.md](./dev/kratos-architecture-audit.md) · [dev/kratos-migration.md](./dev/kratos-migration.md) · [dev/new-api-kratos.md](./dev/new-api-kratos.md) |
| Agent 踩坑 / Session | [.cursor/LESSONS.md](../.cursor/LESSONS.md) · [guidelines/sessions/](./guidelines/sessions/) |

---

## 目录结构

```text
docs/
├── README.md          ← 本文件
├── index.html         ← 浏览器导航
├── dev/               ← 开发、联调、Kratos、推理/记忆 SSOT
├── product/           ← 产品方案与 UI
├── planning/          ← 待实施规划
├── features/          ← 功能说明
├── guidelines/        ← Session 归档（规则见 .cursor/rules/）
├── autoglm/           ← AutoGLM 子系统
├── testing/           ← 测试清单
├── specs/             ← 专项需求规格
└── ideation/          ← 一次性 UX/方案脑暴（非 SSOT）
```

各子目录均有 `README.md` 索引。

---

## 推理与记忆（精简）

| 优先级 | 文档 | 说明 |
|--------|------|------|
| 1 | [llm-inference-and-memory-vision.md](./dev/llm-inference-and-memory-vision.md) | 推理 + 记忆配置 SSOT |
| 2 | [用户记忆系统-OpenClaw式演进设计.md](./dev/用户记忆系统-OpenClaw式演进设计.md) | 记忆库架构、API |
| 2b | [moe-brain-memory-rpg.md](./dev/moe-brain-memory-rpg.md) | 记忆 RPG UI |
| 3 | [记忆系统-2026-05-20-变更整理.md](./dev/记忆系统-2026-05-20-变更整理.md) | 近期变更 |
| 4 | [memory/README.md](./dev/memory/README.md) | 代码目录地图 |

---

## 开发与联调

详见 [dev/README.md](./dev/README.md)。

---

## 产品与设计

详见 [product/README.md](./product/README.md)。

---

## 其他子系统

| 目录 | 入口 |
|------|------|
| AutoGLM | [autoglm/AutoGLM_README.md](./autoglm/AutoGLM_README.md) |
| 功能指南 | [features/NEW_FEATURES_GUIDE.md](./features/NEW_FEATURES_GUIDE.md) |
| 测试 | [testing/E2E测试清单.md](./testing/E2E测试清单.md) |
| 后端私信 | [../backend/docs/private_messages.md](../backend/docs/private_messages.md) |
| 开发者工具台 | [dev/devtools.html](dev/devtools.html) |

---

## 仓库根目录与 backend

| 位置 | 说明 |
|------|------|
| `code_review.md` | Code review 标准 |
| `backend/README.md` | 后端启动与 `make gen` |
| `backend/LAYOUT.md` | 目录地图 |
| `backend/架构说明.md` | HTTP 分层与路由进度 |

新文档请放入 `docs/<category>/`，避免在仓库根目录堆积。

---

## 文档维护约定

1. **一个主题一份 SSOT**，其余只写增量。  
2. **方案落地后**：更新 SSOT 变更记录；过时文档**删除**，不保留 archive stub。  
3. **文件名带日期**表示快照，须在 README 或文首注明是否仍有效。  
4. **推理、记忆、设备、AI Provider** 禁止再开并行架构文档。

---

最后整理：**2026-05-27**（删除 `docs/archive/` · 清理跳转 stub）
