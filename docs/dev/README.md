# 开发与联调文档

> 总索引：[docs/README.md](../README.md) · HTML 导航：[index.html](../index.html)

## 优先阅读（当前有效）

| 文档 | 用途 |
|------|------|
| [ui-upgrade-iteration-2026-08-29.md](./ui-upgrade-iteration-2026-08-29.md) | **当前 Flutter UI 视觉升级迭代** |
| [aurora-arena-ssot.md](./aurora-arena-ssot.md) | **星辉远征（Arena）域 SSOT** |
| [aurora-living-world-plan.md](./aurora-living-world-plan.md) | **星辉活世界方案**（英雄 AI + Life 转向合并，方案已定稿未实施） |
| [full-review-2026-09-02.md](./full-review-2026-09-02.md) | 全栈审查快照（产品方向 / 代码 / UI + P0-P2 行动项） |
| [config-hygiene-review-2026-09-08.md](./config-hygiene-review-2026-09-08.md) | **配置治理审查**（凭据 / 地址多副本 / 真源冲突 / 死配置 / 4 套部署链 + 九批整改记录；**有效收敛率已 100%**，105/105 键只在 `pkg/conf` 内读取） |
| [llm-inference-and-memory-vision.md](./llm-inference-and-memory-vision.md) | **推理服务 + 记忆分层**（2026-09-11 重写配置节：生效值是局域网 Ollama，不是 `api/etc/moe.yaml` 片段里的 llama-server 默认值） |
| [../../backend/LAYOUT.md](../../backend/LAYOUT.md) | **后端目录布局**，含 `pkg/conf` 三个文件的职责与「新增配置项该改哪里」（配置读取 SSOT，49 个反向依赖） |
| [../product/product-positioning.md](../product/product-positioning.md) | 产品定位与边界 |
| [moe-social-runtime.md](./moe-social-runtime.md) | **后端运行时 SSOT**（单进程 Kratos HTTP :8888、启动/生成/冒烟、已废弃命令对照） |
| [环境配置说明.md](./环境配置说明.md) | 本地 / 线上 API 基址 |
| [快速调试步骤.md](./快速调试步骤.md) | Flutter 模拟器与运行 |
| [ports.md](./ports.md) | 本地端口（:8888 业务、:19010 Agent、:5173 Admin）· 含「已无监听者的端口」表；硬编码越界见 [配置治理审查 §4.2](./config-hygiene-review-2026-09-08.md) |
| [API调试指南.md](./API调试指南.md) | 接口调试 |
| [应用配置与全局常量分层约定.md](./应用配置与全局常量分层约定.md) | 配置分层 |
| [打包流程.md](./打包流程.md) | 构建发布 |

## Kratos 后端（运行时 ✅ · D2 ~83%）

| 文档 | 用途 |
|------|------|
| [kratos-migration-status.md](./kratos-migration-status.md) | **当前 / 下一步**（状态板 SSOT） |
| [kratos-architecture-audit.md](./kratos-architecture-audit.md) | P0/P1 100%、路由实测、P2 余量 |
| [kratos-migration.md](./kratos-migration.md) | 架构 SSOT、`make gen` |
| [kratos-directory-ssot.md](./kratos-directory-ssot.md) | 官方目录对齐 |
| [new-api-kratos.md](./new-api-kratos.md) | **新接口开发**（域 proto） |
| [openapi-apifox.md](./openapi-apifox.md) | OpenAPI 3.0 / Apifox |
| [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md) | 存量 compat 历史清单（§2） |
| [kratos-server-layout-migration.md](./kratos-server-layout-migration.md) | `internal/server` 目录收敛 |
| [admin-rpc-runtime-guide.md](./admin-rpc-runtime-guide.md) | 管理台启动、运行时内存指标（⚠️ RPC 监控链路已断，见文内 §0） |
| [kratos-p6-defs-to-proto.md](./kratos-p6-defs-to-proto.md) | P6 契约迁移 |
| [../../backend/LAYOUT.md](../../backend/LAYOUT.md) | 仓库目录 |

## 记忆与智能栈

| 文档 | 用途 |
|------|------|
| [用户记忆系统-OpenClaw式演进设计.md](./用户记忆系统-OpenClaw式演进设计.md) | **记忆架构 SSOT**（⚠️ 向量/Embedding 半边已于 2026-06-29 移除，仅关键词记忆文本库仍有效；见文首横幅） |
| [ai-generation-and-memory-reliability.md](./ai-generation-and-memory-reliability.md) | Companion 记忆任务持久化、Bot 生成质检与迁移/回滚 |
| [Moe-Intelligence-Stack-v1.md](./Moe-Intelligence-Stack-v1.md) | Moe Core v1（⚠️ `moe.default_capability_tier` 是死键，默认档位实为编译期常量） |
| [memory/README.md](./memory/README.md) | 代码模块地图（⚠️ **历史设计**：`pkg/memory`、`backend/rpc`、`lib/memory` 三个目录均已不存在，勿据此找代码） |
| [local-llm-tools.md](./local-llm-tools.md) | 本机 GGUF |
| [moe-brain-memory-rpg.md](./moe-brain-memory-rpg.md) | 记忆 RPG UI |

## 管理台与运维

| 文档 | 用途 |
|------|------|
| [../../moe-admin/README.md](../../moe-admin/README.md) | Moe Admin |
| [moe-admin.md](./moe-admin.md) | 管理台与 API 分工 |
| [deploy-platform.md](./deploy-platform.md) | 云平台部署 |

## 集成与专项

| 文档 | 用途 |
|------|------|
| [飞书OAuth授权验证指南.md](./飞书OAuth授权验证指南.md) | 飞书登录 |
| [flutter_private_messaging_frontend_workflow.md](./flutter_private_messaging_frontend_workflow.md) | 私信前端 |
| [security-and-stability-backlog.md](./security-and-stability-backlog.md) | 安全待办 |
