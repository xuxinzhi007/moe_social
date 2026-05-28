# 开发与联调文档

> 总索引：[docs/README.md](../README.md) · HTML 导航：[index.html](../index.html)

## 优先阅读（当前有效）

| 文档 | 用途 |
|------|------|
| [llm-inference-and-memory-vision.md](./llm-inference-and-memory-vision.md) | **推理服务 + 记忆分层** |
| [../product/moe-app-product-assessment.md](../product/moe-app-product-assessment.md) | 产品成熟度 |
| [环境配置说明.md](./环境配置说明.md) | 本地 / 线上 API 基址 |
| [快速调试步骤.md](./快速调试步骤.md) | Flutter 模拟器与运行 |
| [ports.md](./ports.md) | 本地端口（API 8888、Admin 5173） |
| [API调试指南.md](./API调试指南.md) | 接口调试 |
| [应用配置与全局常量分层约定.md](./应用配置与全局常量分层约定.md) | 配置分层 |
| [打包流程.md](./打包流程.md) | 构建发布 |

## Kratos 后端（2026-05-27 当前阶段）

| 文档 | 用途 |
|------|------|
| [kratos-migration.md](./kratos-migration.md) | **架构 SSOT**（纯 Kratos 生产、`make gen`） |
| [new-api-kratos.md](./new-api-kratos.md) | **新接口开发**（域 proto，勿扩 defs） |
| [kratos-migration-status.md](./kratos-migration-status.md) | 进度勾选 |
| [moe-social-runtime.md](./moe-social-runtime.md) | `make moe-social` 运行时 |
| [kratos-pure-rollout.md](./kratos-pure-rollout.md) | PK 摘要（详情已归档） |
| [../../backend/LAYOUT.md](../../backend/LAYOUT.md) | 仓库目录 |

历史冲刺 / `make verify-*`：[../archive/dev/kratos/](../archive/dev/kratos/)

## 记忆与智能栈

| 文档 | 用途 |
|------|------|
| [用户记忆系统-OpenClaw式演进设计.md](./用户记忆系统-OpenClaw式演进设计.md) | **记忆架构 SSOT** |
| [Moe-Intelligence-Stack-v1.md](./Moe-Intelligence-Stack-v1.md) | Moe Core v1 |
| [memory/README.md](./memory/README.md) | 代码模块地图 |
| [local-llm-tools.md](./local-llm-tools.md) | 本机 GGUF |

历史 Ollama：`../archive/memory/`

## 管理台与运维

| 文档 | 用途 |
|------|------|
| [../../moe-admin/README.md](../../moe-admin/README.md) | Moe Admin |
| [moe-admin.md](./moe-admin.md) | 管理台与 API 分工 |
| [admin-rpc-runtime-guide.md](./admin-rpc-runtime-guide.md) | RPC 监控、进程内存 |
| [goctl-generation-hygiene.md](./goctl-generation-hygiene.md) | goctl 空壳清理 |

## 集成与专项

| 文档 | 用途 |
|------|------|
| [飞书OAuth授权验证指南.md](./飞书OAuth授权验证指南.md) | 飞书登录 |
| [flutter_private_messaging_frontend_workflow.md](./flutter_private_messaging_frontend_workflow.md) | 私信前端 |
| [security-and-stability-backlog.md](./security-and-stability-backlog.md) | 安全待办 |

## 已归档

见 [../archive/dev/](../archive/dev/) 及 `dev/` 下带「已归档」跳转的 stub。
