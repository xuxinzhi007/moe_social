# OpenClaw + Ollama + Moe Social AI 接入方案

> 状态：方案整理（2026-09-04）  
> 目标：在不破坏现有 Companion、记忆和 Provider 架构的前提下，把小主机上的本地模型能力接入 Moe Social，并支持专属 AI 角色。

## 1. 当前已完成

### 小主机

- Debian 13。
- Intel i5-12450H，16 GB 内存，Intel UHD 集显，无独立 GPU。
- OpenClaw `2026.8.2` 运行在 Docker Compose 中。
- Feishu 和 Telegram 渠道已迁移并通过 OpenClaw 校验。
- Ollama 已安装在宿主机（不放进 OpenClaw 容器）。
- `qwen3:4b` 已安装，约 2.5 GB，Q4_K_M，CPU 推理可用。
- Ollama 服务已由 systemd 托管。

### Moe Social 项目

- Flutter 客户端 + Go/Kratos 后端。
- Companion 已有 Profile、聊天 SSE、WebSocket、记忆、关系状态、主动消息和语音链路。
- 现有正式推理 SSOT 是 `llm_inference`，文档默认以 `llama-server` 为推理服务。
- App 也已有 `llamadart` 的离线 GGUF 路线，但该路线主要面向手机/浏览器，不能直接复用小主机 Ollama。

## 2. 能否让 App 支持 AI

**可以，而且项目当前已经具备 AI 功能基础。**

需要注意：OpenClaw 和 Moe Social 是两个不同的调用入口：

```text
飞书 → OpenClaw → Ollama(qwen3:4b)
App → Moe Social 后端 → Ollama(qwen3:4b)
```

不建议让 Flutter 直接访问 Ollama，也不建议让 App 依赖 OpenClaw 的聊天协议。后端负责用户身份、角色配置、记忆、工具权限和模型路由，OpenClaw 只作为飞书/自动化入口。

## 3. 推荐部署拓扑

```text
                         ┌─ Feishu
用户 ────────────────────┤
                         └─ Moe Social App
                              │ JWT / SSE / WS
                              ▼
                    Moe Social Go/Kratos Backend
                    ├─ Companion / Context Orchestrator
                    ├─ Memory / Relationship / Safety
                    ├─ Provider Router
                    └─ Ollama Adapter
                              │ HTTP /api/chat
                              ▼
                    Ollama（宿主机 :11434）
                              └─ qwen3:4b

OpenClaw Docker ──────────────┘（仅在需要共享模型时）
```

Ollama 是独立服务，OpenClaw 和后端都是客户端。模型文件只保留一份，避免 Docker 容器和宿主机重复占用磁盘。

## 4. 模型建议

### 小主机默认模型

```text
ollama/qwen3:4b
```

适合中文角色、普通 Companion 聊天、记忆摘要和低频工具调用。建议限制上下文长度，避免 16 GB 内存被长对话占满。

### 备选

| 模型 | 用途 | 建议 |
|---|---|---|
| `qwen2.5:3b` | 更快的陪伴聊天 | 低延迟优先时使用 |
| `qwen2:7b` | 更强的复杂理解 | 可运行，但不作为默认常驻模型 |
| 手机 GGUF 0.5B/1.5B | 完全离线 App | 保留现有 `llamadart` 路线，不与 Ollama 混用 |

小主机没有独立 GPU，不建议在其上运行 SDXL、Flux 或其他图片生成模型。图片生成应使用外部 API 或独立 GPU 主机；文字模型与图片模型分开路由。

## 5. App 接入边界

### 后端新增/调整

在现有 `llm_inference` 抽象下增加 Ollama provider，不重新开一套 Companion 聊天协议：

- `base_url`：小主机可访问的 `http://<host>:11434`，不要加 `/v1`。
- `api_style`：原生 Ollama `/api/chat`，或在适配层转换为项目内部统一接口。
- `model`：`qwen3:4b`。
- 流式输出：转换成现有 Companion SSE 格式。
- 工具调用：由后端校验工具白名单和用户权限，不能把任意系统命令暴露给模型。
- 失败回退：Ollama 不可用时回退到现有云 Provider，或返回明确的服务不可用状态。

建议配置形态：

```yaml
llm_inference:
  provider: ollama
  base_url: http://192.168.124.77:11434
  model: qwen3:4b
  api_style: ollama
  timeout_seconds: 120
```

实际字段以当前 `backend/config/config.yaml` 和 Provider 代码为准；不要恢复旧的独立 `ollama.*` 双配置入口。

### Flutter 保持不变的部分

- 继续调用 `CompanionService`、SSE 和现有 DTO。
- 不在 Flutter 拼接系统 Prompt。
- 不在客户端保存 Ollama 凭据。
- 继续使用现有 `CompanionInteractionCoordinator`、记忆页和关系事件。

## 6. 专属 AI 角色实现

角色不是重新训练模型，第一阶段使用“模型 + 角色配置 + 记忆”组合：

1. `Companion Profile`：名称、头像、关系阶段、表达风格。
2. 角色 Prompt：写入后端角色配置或 Companion 资源，不写死在 Flutter。
3. `USER.md`/长期记忆对应数据库中的用户记忆，不把完整聊天历史塞进 system prompt。
4. Context Orchestrator 按固定顺序注入：安全约束 → 角色 → 关系 → 已确认记忆 → 最近对话 → 工具权限。
5. 低风险记忆自动提取，高敏感信息必须用户确认。

这样可以实现专属称呼、语气、背景、关系成长和长期连续性；模型供应商的内容安全策略仍然适用，单用户使用不等于可以关闭安全约束。

## 7. 实施阶段

### Phase 0：连通性验证

- Docker 容器能访问宿主机 `11434`。
- 后端调用 `/api/tags` 和 `/api/chat` 成功。
- 用 `qwen3:4b` 完成一次流式中文回复。

### Phase 1：后端 Provider 接入

- 在现有 `llm_inference` 中加入 Ollama adapter。
- 复用现有 SSE、超时、日志和错误码。
- 添加 Provider 单元测试和本地联调配置。
- 默认不改变线上云模型，增加可切换的本地 Provider。

### Phase 2：Companion 角色闭环

- 角色编辑页保存 Profile/Prompt。
- 聊天请求接入统一 Context Orchestrator。
- 记忆提取、确认、冲突和删除继续走现有数据库流程。
- 增加模型耗时、首 token、错误率和记忆命中指标。

### Phase 3：本地模型默认化

- 只在小主机稳定运行后，将指定环境默认模型切为 `ollama/qwen3:4b`。
- 保留云 Provider 作为故障回退。
- 增加模型切换和管理员可观测入口。

### Phase 4：图片/语音

- 图片理解：另行选择支持 vision 的模型或云 Provider。
- 图片生成：外部 API/独立 GPU 服务，不部署到当前小主机。
- 语音：复用现有 STT/TTS，文字推理继续走 Ollama。

## 8. 安全与运维要求

- Ollama `11434` 只允许局域网/内部 Docker 网段访问，不暴露公网。
- Feishu、Telegram、Ollama 和服务账号凭据放入环境变量或密钥目录，不提交 Git。
- OpenClaw 继续保留 Docker volume 和配置备份。
- 后端必须按 JWT actor user ID 隔离 Companion、记忆和聊天记录。
- 工具调用采用白名单、参数校验、超时和审计日志。
- 角色 Prompt 只能改变表达和行为偏好，不能成为绕过权限或安全检查的通道。
- 小主机磁盘只有约 120 GB，建议只保留一个 4B 主模型和必要缓存。

## 9. 当前结论

当前已经具备：

- OpenClaw + Feishu 私人入口。
- 小主机 Ollama + `qwen3:4b` 本地推理。
- Moe Social Companion、记忆和关系数据层。

尚未完成的是：**Moe Social 后端的 Ollama Provider 适配，以及 Docker/后端到宿主机 `11434` 的连通验证。**完成这两项后，App 就能使用小主机本地模型；专属角色定制则主要在 Companion Profile、Prompt 和记忆层实现。

## 10. 验收清单

- [ ] `curl http://<ollama-host>:11434/api/tags` 可从后端运行环境访问。
- [ ] 后端 SSE 能返回 `qwen3:4b` 的完整回复。
- [ ] 角色配置只影响对应用户和 Companion。
- [ ] 记忆保存、确认、删除后对下一轮对话生效。
- [ ] Ollama 停止时能回退云 Provider 或显示可理解错误。
- [ ] Feishu、App、OpenClaw 三条入口的会话和权限互不串线。
- [ ] 11434 未暴露到公网，凭据未进入日志和 Git。
