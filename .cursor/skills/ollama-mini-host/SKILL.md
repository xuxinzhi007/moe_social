---
name: ollama-mini-host
description: 调用、诊断和接入局域网小主机上的 Ollama 模型，适用于 Moe Social 后端、Companion 聊天、OpenClaw 共用模型和连通性排查。
---

# 小主机 Ollama 调用 Skill

## 目标与边界

本仓库的推荐链路是：

```text
Flutter App → Moe Social Go/Kratos 后端 → Ollama（小主机:11434）
OpenClaw Docker ────────────────────────→ Ollama（小主机:11434）
```

- App 不直接依赖 Ollama 或 OpenClaw 协议；身份、Companion、记忆、工具权限和回退由后端处理。
- Ollama 只在局域网或 Docker 内网开放，不暴露公网。
- 当前适合小主机 CPU 推理的默认模型是 `qwen3:4b`；不要假定模型一定存在，先查 `/api/tags`。
- 图片生成、GPU 专用模型和手机离线 GGUF 不属于这条调用链。

## 当前仓库的配置

统一配置 SSOT 是 `backend/config/config.yaml` 的 `llm_inference`。旧的 `ollama.*` 仅作兼容读取，不要新增第二套配置入口：

```yaml
llm_inference:
  provider: ollama
  base_url: http://<小主机局域网地址>:11434
  model: qwen3:4b
  api_style: ollama
  timeout_seconds: 120
```

关键实现位置：

- `backend/pkg/llminference/client.go`：模型列表、非流式 `/api/chat`。
- `backend/pkg/llminference/stream.go`：流式 `/api/chat`，逐行解析 Ollama JSON。
- `backend/internal/adapter/moeconfig/inference.go`：读取统一配置。
- `docs/dev/openclaw-ollama-moe-social-integration-plan.md`：部署拓扑和验收清单。

## 标准调用流程

### 1. 先确认 Ollama 服务和模型

在小主机执行：

```bash
systemctl status ollama --no-pager
curl -fsS http://127.0.0.1:11434/api/tags
ollama list
```

没有模型时再执行 `ollama pull qwen3:4b`。不要在应用启动时自动下载大模型。

### 2. 从后端运行环境测试网络

必须从“后端实际运行环境”测试，而不是只在小主机本机测试：

```bash
curl -fsS http://<小主机地址>:11434/api/tags
```

若后端在 Docker 中，使用宿主机可达地址（Linux 通常是局域网 IP 或 Docker 网关），不要使用后端容器自己的 `localhost`。

### 3. 直接验证一次对话

Ollama 原生接口不加 `/v1`：

```bash
curl -fsS http://<小主机地址>:11434/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3:4b","messages":[{"role":"user","content":"用一句中文介绍你自己"}],"stream":false}'
```

成功响应应包含 `message.content`。流式请求将 `stream` 改为 `true`，响应是逐行 JSON，不是 OpenAI SSE。

### 4. 验证 Moe Social 后端链路

配置 `llm_inference` 后，在 `backend/` 执行：

```bash
make check
go test ./pkg/llminference/... ./internal/adapter/moeconfig/...
```

再通过现有 Companion/API 入口发起一次中文对话，确认后端日志不打印 API Key、完整 Prompt 或响应正文。

## 故障排查顺序

1. `/api/tags` 失败：检查 Ollama systemd 状态、监听地址、防火墙和端口 `11434`。
2. `/api/tags` 成功但模型不存在：模型名与配置不一致，使用返回的 `name` 原样配置。
3. `/api/chat` 超时：先缩短上下文或换 `qwen2.5:3b`，再调整 `timeout_seconds`；不要无限增大超时。
4. 后端能访问但 App 失败：检查 App 是否仍走后端 API、JWT、SSE/WS，而不是把小主机地址硬编码进页面。
5. Ollama 停止：应触发现有云 Provider 回退或给用户可理解的失败提示，不要静默伪造回复。

## 安全与运维

- `11434` 仅允许局域网/内部 Docker 网段；不要配置公网反向代理。
- Ollama、Feishu、Telegram 等凭据放环境变量或密钥目录，不提交 Git。
- 后端工具调用必须经过白名单、参数校验、超时和审计；不能把任意 shell 命令交给模型。
- 小主机约 16 GB 内存时，优先常驻一个 4B 模型；避免并发拉起多个大模型。
- 修改 `backend/api/**` 或配置契约时，按仓库规则运行 `make gen`；只改运行配置时无需重新生成 Proto。

## 完成判定

- 后端运行环境能访问 `/api/tags`。
- `/api/chat` 能返回目标模型的中文回复。
- Moe Social Companion 能通过后端完成一次流式回复。
- Ollama 停止时有回退或明确错误。
- 11434 未暴露公网，模型调用链未绕过后端权限和记忆边界。
