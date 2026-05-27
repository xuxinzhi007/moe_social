# 开发与联调文档

> 总索引：[docs/README.md](../README.md) · HTML 导航：[index.html](../index.html)

## 优先阅读（当前有效）

| 文档 | 用途 |
|------|------|
| [llm-inference-and-memory-vision.md](./llm-inference-and-memory-vision.md) | **推理服务 + 记忆分层**（llama-server、配置键、产品对齐） |
| [../product/moe-app-product-assessment.md](../product/moe-app-product-assessment.md) | 产品成熟度（官网 vs App、Admin） |
| [环境配置说明.md](./环境配置说明.md) | 本地 / 线上 API 基址 |
| [快速调试步骤.md](./快速调试步骤.md) | Flutter 模拟器与运行 |
| [ports.md](./ports.md) | 本地端口（API 8888、Admin 5173、Agent 19010） |
| [API调试指南.md](./API调试指南.md) | 接口调试 |
| [应用配置与全局常量分层约定.md](./应用配置与全局常量分层约定.md) | 配置分层 |
| [打包流程.md](./打包流程.md) | 构建发布 |
| [android-release-signing.md](./android-release-signing.md) | Android 签名 |

## 记忆与智能栈

| 文档 | 用途 |
|------|------|
| [llm-inference-and-memory-vision.md](./llm-inference-and-memory-vision.md) | 推理配置与记忆「学习」路径 |
| [用户记忆系统-OpenClaw式演进设计.md](./用户记忆系统-OpenClaw式演进设计.md) | **记忆架构 SSOT** |
| [Moe-Intelligence-Stack-v1.md](./Moe-Intelligence-Stack-v1.md) | Moe Core v1（工具 / Post Pulse / Bot Runtime） |
| [记忆系统-2026-05-20-变更整理.md](./记忆系统-2026-05-20-变更整理.md) | 近期变更与验收 |
| [记忆系统-开源对标调研.md](./记忆系统-开源对标调研.md) | OpenClaw / 酒馆对标 |
| [用户级记忆统一改造验收脚本.md](./用户级记忆统一改造验收脚本.md) | E2E 验收 |
| [memory-system-dashboard.html](./memory-system-dashboard.html) | 记忆监控台 |
| [memory/README.md](./memory/README.md) | 代码模块地图 |
| [local-llm-tools.md](./local-llm-tools.md) | App 内本机 GGUF + 工具调用 |
| [local-model-download.md](./local-model-download.md) | 离线模型下载 |

历史 Ollama 记忆文档：`ollama用户级记忆*.md` 为跳转 stub，全文在 [../archive/memory/](../archive/memory/)。

## 管理台与运维

| 文档 | 用途 |
|------|------|
| [../../moe-admin/README.md](../../moe-admin/README.md) | Moe Admin 启动 |
| [moe-admin.md](./moe-admin.md) | 管理台与 API/Agent 分工 |
| [admin-rpc-runtime-guide.md](./admin-rpc-runtime-guide.md) | **开发启动、RPC 监控（React）、进程内存** |
| [moe-admin-menu-map.md](./moe-admin-menu-map.md) | 菜单与路由 |
| [../../moe-admin/docs/admin-design-system.md](../../moe-admin/docs/admin-design-system.md) | 管理台设计参考 |
| [deploy-platform.md](./deploy-platform.md) | 部署分工 SSOT |
| [devtools.html](./devtools.html) | 开发者工具台 |
| [tools/rpc-monitor.html](./tools/rpc-monitor.html) | RPC 监控（遗留 HTML；管理台请用 [admin-rpc-runtime-guide](./admin-rpc-runtime-guide.md)） |

## 集成与专项

| 文档 | 用途 |
|------|------|
| [飞书OAuth授权验证指南.md](./飞书OAuth授权验证指南.md) | 飞书登录 |
| [飞书通知与绑定.md](./飞书通知与绑定.md) | 飞书通知 |
| [flutter_private_messaging_frontend_workflow.md](./flutter_private_messaging_frontend_workflow.md) | 私信前端流程 |
| [虚拟角色MVP接入说明.md](./虚拟角色MVP接入说明.md) | 虚拟角色 |
| [security-and-stability-backlog.md](./security-and-stability-backlog.md) | 安全待办 |
| [个人开发可用性基线清单.md](./个人开发可用性基线清单.md) | 个人开发基线 |

## 测试与质量

| 文档 | 用途 |
|------|------|
| [登录注册首页冒烟测试清单.md](./登录注册首页冒烟测试清单.md) | 冒烟 |
| [响应式页面模板与检查清单.md](./响应式页面模板与检查清单.md) | 响应式 |
| [调试闪退问题指南.md](./调试闪退问题指南.md) | 闪退排查 |
| [Android真机调试说明.md](./Android真机调试说明.md) | 真机 |
| [本地开发包与正式包隔离维护说明.md](./本地开发包与正式包隔离维护说明.md) | 包隔离 |

## 已归档（勿作主维护）

见 [../archive/dev/](../archive/dev/) 及根目录同名 stub 文件。
