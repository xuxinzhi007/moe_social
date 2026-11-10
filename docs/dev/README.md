# 开发与联调文档

> 总索引：[docs/README.md](../README.md) · 开发者路由：[CONTRIBUTING.md](../CONTRIBUTING.md)

## 优先阅读（当前有效）

| 文档 | 用途 |
|------|------|
| [moe-social-runtime.md](./moe-social-runtime.md) | **后端运行时 SSOT**（单进程 Kratos HTTP :8888、启动/生成/冒烟、已废弃命令对照） |
| [new-api-kratos.md](./new-api-kratos.md) | **当前路由架构 SSOT / 新接口开发**（域 proto） |
| [ports.md](./ports.md) | 本地端口（:8888 业务、:19010 Agent）· 含「已无监听者的端口」表 |
| [环境配置说明.md](./环境配置说明.md) | 本地 / 线上 API 基址 |
| [快速调试步骤.md](./快速调试步骤.md) | Flutter 模拟器与运行 |
| [API调试指南.md](./API调试指南.md) | 接口调试 |
| [应用配置与全局常量分层约定.md](./应用配置与全局常量分层约定.md) | 配置分层 |
| [打包流程.md](./打包流程.md) | 构建发布 |
| [../product/product-positioning.md](../product/product-positioning.md) | 产品定位与边界 |
| [../../backend/LAYOUT.md](../../backend/LAYOUT.md) | 后端目录布局 + 配置项该改哪里 |

## Kratos 后端

| 文档 | 用途 |
|------|------|
| [new-api-kratos.md](./new-api-kratos.md) | 当前路由架构 SSOT |
| [kratos-migration-history.md](./kratos-migration-history.md) | 迁移历史归档（阶段、审计结论、目录决策、P6 过程） |
| [openapi-apifox.md](./openapi-apifox.md) | OpenAPI 3.0 / Apifox |
| [admin-rpc-runtime-guide.md](./admin-rpc-runtime-guide.md) | 管理台启动、运行时内存指标（⚠️ RPC 监控链路已断，见文内 §0） |
| [backend-business-logic-ownership.md](./backend-business-logic-ownership.md) | 业务逻辑归属边界 |
| [backend-business-ssot-transition.md](./backend-business-ssot-transition.md) | 业务事实源向后端收口 |

## 安全与稳定

| 文档 | 用途 |
|------|------|
| [security-and-stability-backlog.md](./security-and-stability-backlog.md) | **安全与稳定性待办 + 配置治理结论**（含登记不修的 #47 改密无验证码、#50 OAuth 开放重定向） |

## 记忆与智能栈

| 文档 | 用途 |
|------|------|
| [用户记忆系统-OpenClaw式演进设计.md](./用户记忆系统-OpenClaw式演进设计.md) | **记忆架构 SSOT**（⚠️ 向量/Embedding 半边已于 2026-06-29 移除，仅关键词记忆文本库仍有效；见文首横幅） |
| [llm-inference-and-memory-vision.md](./llm-inference-and-memory-vision.md) | **推理服务 + 记忆分层** SSOT |
| [ai-generation-and-memory-reliability.md](./ai-generation-and-memory-reliability.md) | Companion 记忆任务持久化、Bot 生成质检与迁移/回滚 |
| [Moe-Intelligence-Stack-v1.md](./Moe-Intelligence-Stack-v1.md) | Moe Core v1（⚠️ `moe.default_capability_tier` 是死键，默认档位实为编译期常量） |
| [local-llm-tools.md](./local-llm-tools.md) | 本机 GGUF |
| [moe-brain-memory-rpg.md](./moe-brain-memory-rpg.md) | 记忆 RPG UI |

## AI 伙伴与世界

| 文档 | 用途 |
|------|------|
| [ai-companion-architecture.md](./ai-companion-architecture.md) | Companion 架构 |
| [ai-companion-formal-decisions.md](./ai-companion-formal-decisions.md) | Companion 正式决策记录 |
| [ai-companion-plaza-merge-handoff.md](./ai-companion-plaza-merge-handoff.md) | 身份卡广场并入陪伴的交接（2026-11-10，代码未改） |
| [aurora-arena-ssot.md](./aurora-arena-ssot.md) | **星辉远征（Arena）域 SSOT** |
| [aurora-living-world-plan.md](./aurora-living-world-plan.md) | 星辉活世界方案（方案已定稿，未实施） |

## 管理台与运维

| 文档 | 用途 |
|------|------|
| [moe-admin.md](./moe-admin.md) | 管理台总览：选型分工、模块索引（前端已独立成仓） |
| [moe-avatar-admin.md](./moe-avatar-admin.md) | 角色装扮 / 序列帧生产力工具（已落地 `/ops/biz/pet/avatar`） |
| [deploy-platform.md](./deploy-platform.md) | 云平台部署 / Deploy Agent |
| [n100-pipeline.md](./n100-pipeline.md) | n100 部署流水线 |
| [ssh-reverse-tunnel-vps.md](./ssh-reverse-tunnel-vps.md) | SSH 反向隧道 |

## 集成与专项

| 文档 | 用途 |
|------|------|
| [飞书OAuth授权验证指南.md](./飞书OAuth授权验证指南.md) | 飞书登录 |
| [飞书通知与绑定.md](./飞书通知与绑定.md) | 飞书通知 |
| [flutter_private_messaging_frontend_workflow.md](./flutter_private_messaging_frontend_workflow.md) | 私信前端 |
| [live-gift-pk-v1.md](./live-gift-pk-v1.md) | 直播礼物 PK |
| [voice-ws-boundary.md](./voice-ws-boundary.md) | 语音 WS 边界 |
| [flutter-motion-system.md](./flutter-motion-system.md) | Flutter 动效系统 |
| [ui-component-consolidation.md](./ui-component-consolidation.md) | UI 组件收拢 |
| [cross-platform-dev.md](./cross-platform-dev.md) | 跨平台开发 |
| [codegraph.md](./codegraph.md) | 代码图谱工具 |
