# Moe Social 文档中心

> **原则**：只维护「当前有效」文档；过时内容直接删除，不保留 `archive/` 跳转 stub。
> **本地预览**：`cd docs && python3 -m http.server 8765` → [index.html](./index.html)

**新来这里？** → [CONTRIBUTING.md](./CONTRIBUTING.md)（开发者路由页，按「我要做什么」分流）

---

## 快速入口

| 我想… | 去看 |
|--------|------|
| **第一次把项目跑起来** | [CONTRIBUTING.md](./CONTRIBUTING.md) · [dev/环境配置说明.md](./dev/环境配置说明.md) · [dev/ports.md](./dev/ports.md) |
| **了解产品要做什么** | [product/product-positioning.md](./product/product-positioning.md) · [product/prd/](./product/prd/) |
| **改后端 / 加接口** | [dev/new-api-kratos.md](./dev/new-api-kratos.md) · [../backend/LAYOUT.md](../backend/LAYOUT.md) |
| **改 Flutter 页面** | [../AGENTS.md](../AGENTS.md) · [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) |
| **改管理台 admin 契约** | [../backend/api/admin/v1/README.md](../backend/api/admin/v1/README.md)（前端已独立成仓） |
| **看有哪些安全问题待办** | [dev/security-and-stability-backlog.md](./dev/security-and-stability-backlog.md) |
| **发版 / 运维** | [dev/app-release-cheatsheet.md](./dev/app-release-cheatsheet.md) · [dev/deploy-platform.md](./dev/deploy-platform.md) |
| **OpenAPI / Apifox 同步** | [dev/openapi-apifox.md](./dev/openapi-apifox.md) |
| **开发规范** | [../AGENTS.md](../AGENTS.md) · [../code_review.md](../code_review.md) |
| **Agent 踩坑记录** | [../.cursor/LESSONS.md](../.cursor/LESSONS.md) |

---

## 目录结构

```text
docs/
├── README.md          ← 本文件（总索引）
├── CONTRIBUTING.md    ← 开发者路由页
├── index.html         ← 浏览器导航
├── DESIGN_SYSTEM.md   ← Flutter 设计系统 SSOT
├── dev/               ← 开发、联调、Kratos、推理/记忆 SSOT
├── product/           ← 产品方案、PRD 与 UI
├── planning/          ← 待实施规划
├── features/          ← 功能说明
├── guidelines/        ← Session 归档
├── autoglm/           ← AutoGLM 子系统
├── testing/           ← 测试清单
├── specs/             ← 专项需求规格
└── ideation/          ← 一次性 UX/方案脑暴（非 SSOT）
```

各子目录均有 `README.md` 索引。

---

## 核心 SSOT

一个主题只有一份 SSOT，改之前先确认你读的是它。

| 主题 | SSOT |
|------|------|
| 路由架构 / 新接口开发 | [dev/new-api-kratos.md](./dev/new-api-kratos.md) |
| 后端运行时（启动/端口/冒烟） | [dev/moe-social-runtime.md](./dev/moe-social-runtime.md) |
| 本地端口分配 | [dev/ports.md](./dev/ports.md) |
| 后端目录布局与配置入口 | [../backend/LAYOUT.md](../backend/LAYOUT.md) |
| 产品定位与边界 | [product/product-positioning.md](./product/product-positioning.md) |
| Flutter 设计系统 | [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) · `lib/theme/moe_tokens.dart` |
| 星辉远征（Arena） | [dev/aurora-arena-ssot.md](./dev/aurora-arena-ssot.md) |
| 推理服务 + 记忆分层 | [dev/llm-inference-and-memory-vision.md](./dev/llm-inference-and-memory-vision.md) |
| 安全与稳定性待办 | [dev/security-and-stability-backlog.md](./dev/security-and-stability-backlog.md) |

---

## 其他子系统

| 目录 | 入口 |
|------|------|
| AutoGLM | [autoglm/AutoGLM_README.md](./autoglm/AutoGLM_README.md) |
| 功能指南 | [features/NEW_FEATURES_GUIDE.md](./features/NEW_FEATURES_GUIDE.md) |
| 测试 | [testing/E2E测试清单.md](./testing/E2E测试清单.md) |
| 后端私信 | [../backend/docs/private_messages.md](../backend/docs/private_messages.md) |

---

## 文档维护约定

1. **一个主题一份 SSOT**，其余只写增量。
2. **方案落地后**：更新 SSOT 变更记录；过时文档**删除**，不保留 archive stub。
3. **文件名带日期**表示一次性快照，用完后**删除**，不要留在索引里。
4. **推理、记忆、设备、AI Provider** 禁止再开并行架构文档。

最后整理：**2026-11-04**（① 删除 13 份已失效/一次性快照文档；② `config-hygiene-review-2026-09-08.md`（3404 行）有效结论并入 `security-and-stability-backlog.md` 后删除；③ 根 README 转为面向用户，开发内容迁入新建的 `CONTRIBUTING.md`）
