# 推理服务与记忆系统（SSOT）

> **推理（当前生效值）**：局域网 n100 小主机上的 **Ollama** `http://192.168.124.77:11434`，`api_style: ollama`，`memory_model: qwen2.5:3b-instruct`（`backend/config/config.yaml:112-123`）。  
> **记忆**：**数据库**为长期存储；**单次 prompt** 为工作上下文（受 n_ctx 限制）。
>
> ⚠️ 别照 `api/etc/moe.yaml` 片段里的 `BaseUrl: http://127.0.0.1:6633` / `ApiStyle: openai` 去配——那是**结构模板的默认值**，
> 启动时被 `config/config.yaml` 的 `llm_inference` 段覆盖（`wiring/config_override.go:21-33`，仅当值非空/为正才覆盖）。
> 本机 llama-server（OpenAI 兼容，:6633）是**另一种可选部署**，不是当前状态。

## 配置

**读取入口只有一个**：`conf.Inference()`（返回归一化后的 `llminference.Config`）；
需要原值时用 `conf.ResolveInference()`（不去末尾斜杠、不推断 `api_style`、不兜底超时），文字游戏独立端点用 `conf.GameInference()`。

| 键 | 说明 | 当前值 |
|----|------|--------|
| `llm_inference.base_url` | 后端进程可访问的推理端点（**不是** Flutter 客户端地址） | `http://192.168.124.77:11434` |
| `llm_inference.api_style` | `ollama` 或 `openai`；留空时按 URL 是否含 `:11434` 推断，否则判为 openai（`llminference.ResolveAPIStyle`） | `ollama` |
| `llm_inference.memory_model` | 记忆提取/总结用模型，同时是 `Inference().DefaultModel` 的来源 | `qwen2.5:3b-instruct` |
| `llm_inference.timeout_seconds` | ≤0 时兜底 120s（`llminference.ConfigFrom`） | `120` |
| `api/etc/moe.yaml` 片段 | 驼峰字段名 `LLMInference`（`apiconfig.LLMInferenceConf`，`json`/`yaml` tag）；**apiconfig 里没有 `Ollama` 字段**，历史 `ollama.*` 回退只存在于 `pkg/conf/derive.go:55` | 仅作结构模板 |

环境变量 `MOE_LLM_BASE_URL` / `MOE_LLM_API_STYLE` / `MOE_LLM_MODEL` / `MOE_LLM_API_KEY` 优先于文件，第九批后四者作用域统一（此前只有 `API_KEY` 能到达 Bot 调度）。

`backend/config/config.yaml` 中的 `ollama.*` 仅作**读取兼容**（当前整段被注释，`:138-142`），新部署勿再配置。
该注释块里遗留了一个 ngrok 公网隧道地址——**不要照着启用**：无认证 Ollama 暴露到公网等于把小主机交出去，模型写入接口也只应在后端可信网络内可达。

## 对话要不要存库、要不要「学习」？

**建议：要存，但要分层。**

| 层级 | 存什么 | 用途 |
|------|--------|------|
| **会话日志** | 每轮 user/assistant（可选 tool） | 审计、回放、运营看过程 |
| **长期记忆** | `user_memories`（key/value/type） | 跨会话事实，检索后注入 prompt |
| **日观察** | `daily_note:YYYY-MM-DD` | OpenClaw 式当日流水，再提炼 |
| **Bot 自传** | `moe_bot_episodes` | 社区 Bot 人格与发帖风格 |

**「学习」**在本项目指：

1. **回合后异步提取**（`extractAndSaveMemories`，已有）→ 写入 `user_memories`  
2. **聊天前检索注入**（`memory_search` / 混合检索）→ 不塞全库  
3. **Bot 发帖** → `BuildPostMemoryBlock` 拼【Bot 记忆】（非 tool）  
4. **主动行为** → Bot 调度 `RunOnce`、智能发送、日后可扩展「主动 DM」

不要把整段对话原文长期塞进 system prompt；应 **提取 durable 事实 + 摘要旧对话**（`summarizeMessages` 已有）。

## 产品目标对齐

| 目标 | 实现路径 |
|------|----------|
| 自动学习 | 回合后提取 + 工具 `memory_save` + Bot 自传入库 |
| 减少 AI 腔/模板化 | `sanitizePersonaResponse`、发帖 `novelStyleScore`、禁止/偏好标签 |
| 「自主意识」 | 人格锚点记忆 + Bot `system_prompt` + 自传；非无限自主 agent |
| 主动发信息 | RPC Bot 调度 / 智能发送；可扩展 cron + 条件触发 |
| 自己收集数据 | `post_search`、`memory_search`、工具审计 `moe_tool_calls` |

## 小模型与上下文

- **DB ≠ context**：库可很大；每次只取 Top-K + 截断。  
- **压缩**：优先规则截断 + 对话摘要；可选「记忆摘要」专用 prompt。  
- **上下文上限**：从 llama-server 配置/`n_ctx` 读取（待管理台展示）；prompt 侧用 token 估算。

## Bot 发帖话题分析（避模板）

- 发帖成功或试跑被拒时：`brain.AnalyzeAndTagContent` 用 **规则 + 可选 LLM** 打标签，写入 `moe_bot_episodes.tags_json` 与 `moe_agent_topic_stats`（按 agent 累计场景/活动/主题使用次数）。  
- 生成前注入 `BuildTopicDiversityBlock`：列出 DB 中「近期过多」话题，并给出可换角度建议。  
- 可选配置 `moe.topic_analyze_model`（默认回退 `llm_inference.memory_model`）；LLM 不可用或 0.5B 解析失败时 **自动仅用规则**，不阻塞发帖。

## 记忆 RPG（管理台游戏化层）

Bot 自传 consolidation 的游戏化入口（标记-清扫压缩、自主思考、2D 观察 UI）见 **[moe-brain-memory-rpg.md](./moe-brain-memory-rpg.md)**。与本文关系：入梦/整理/压缩在有 `llm_inference` 时走 LLM，否则规则 fallback；压缩必须先算法聚类再可选模型改写。

## 受管派生模型（用户隔离）

小主机上的 Ollama 是**共享资源**：任何写入都会影响所有人。因此服务端派生模型走「用户隔离」而不是开放 modelfile 上传。

**所有权只来自 JWT + `llm_managed_models` 表**。角色卡 JSON（`model_name` / `created_by_user_id`）是用户可任意提交的，**不作为所有权依据**；公开角色卡投影会把私有受管名替换回基座（`internal/data/ai/managed_projection.go`）。

| 环节 | 规则 |
|------|------|
| 命名 | 服务端生成 `moe-user-<随机 hex>:latest`，客户端不能指定 |
| 基座 | 必须在 `llm_inference.model_management.allowed_base_models` 内（空列表 ⇒ 只允许当前 `memory_model`）；拒绝 `moe-user-` 前缀、路径、`sha256`、blob 引用 |
| 前提 | 角色卡必须已保存；每次调用带 `agent_id` + `request_id`，缺任一项 400 |
| 配额 | 默认每人 3、全站 12、同时 1 个写操作；`pending`/`unknown`/`deleting` 都占配额，重启不清零 |
| 幂等 | 同 `request_id` + 同意图指纹 ⇒ 重放当前状态；同 ID 不同意图或有未决写入 ⇒ 409 |
| 状态 | `pending → ready / failed / unknown`；发送后超时或断连记 `unknown`，**不自动重建、不释放配额** |
| 对账 | `POST .../reconcile` 按需 `/api/show` 取证：比对 `system` 与基座 modelfile 的 `FROM/ADAPTER sha256-*` 层；仅名字存在不算成功 |
| 删除 | 必须显式带新的 `request_id`；上游 404 视为已删除；只有确认删除才释放配额并把角色卡 `model_name` 回落基座 |
| 绑定 | 上游创建成功后，在事务内比对角色卡快照未变才写 `model_name`；用户已改动 ⇒ `binding_applied=false`，不覆盖 |

**部署前提：单进程。** 写操作并发由进程内协调器 + DB 唯一约束兜底，不支持多副本调度。

## API

| 端点 | 说明 |
|------|------|
| `POST /api/llm/agents` | 为本人角色卡创建/同步受管模型，返回 `LlmManagedModelResp`（`state` / `binding_applied` / `retryable`）；仅 `api_style=ollama`，否则 400 |
| `GET /api/llm/managed-models` | 本人受管模型列表（含无角色卡的孤立模型），需登录 |
| `GET /api/llm/managed-models/{agent_id}` | 按角色卡查状态，客户端丢响应也能找回 |
| `POST /api/llm/managed-models/{agent_id}/reconcile` | 重查未决结果，绝不重发写入 |
| `DELETE /api/llm/managed-models/{agent_id}` | 显式删除，`request_id` 走 query 或 body |
| `GET /api/llm/models` · `/api/llm/models/raw` | **可选 JWT**：匿名只见允许基座；带有效 token 追加本人 ready 模型；token 无效 ⇒ 401（不静默降级为匿名） |
| `POST /api/llm/chat/raw` · `/api/llm/show/raw` | 原生协议透传，但**不是**盲转发：请求体经受限 DTO 重建（≤1 MiB、消息 ≤256、采样参数范围校验、Ollama 参数落 `options` + `think=false`、token 上限 `num_predict`）；`show` 是 Ollama 专有，openai 模式返回 400 |
| `GET /api/llm/config` | 返回扁平 `inference_api_style` / `inference_timeout_sec` / `supports_model_management` / `model_sync_timeout_seconds` / `memory_*`；**不再返回 `inference_base_url`**，任何情况下不返回 `api_key` |

**凭据隔离**：上游请求只携带服务端配置的 `Authorization`；入站 JWT / Cookie 一律剥离，禁止重定向带凭据到其他地址（`pkg/llminference/http.go`）。依赖缺失时 raw 端点 fail closed 返回 503，不回退到无权限校验的分支。

### 新增配置

```yaml
llm_inference:
  model_management:
    user_quota: 3
    global_quota: 12
    write_concurrency: 1
    model_sync_timeout_seconds: 120
    allowed_base_models: []   # 空 = 仅允许当前默认模型，不是「允许全部」
```

### 迁移

`llm_managed_models` 已注册进 `utils/migrate_registry.go`。首次上线执行既有定向迁移即可；表内含 `owner_id+agent_id` 与 `managed_name` 唯一约束，是配额与幂等的兜底。

### 真实联调步骤（小主机开机后）

1. 确认后端进程能访问 `llm_inference.base_url`，且基座模型已 `ollama pull` 到本机（后端不会自动下载）。
2. 跑迁移，`GET /api/llm/config` 应返回 `supports_model_management: true`。
3. 两个账号各建一张角色卡，分别创建派生模型，互相猜名字访问应被 403。
4. 验证聊天、`reconcile`、显式删除，并确认删除后角色卡 `model_name` 回落到基座。
5. 小主机只对后端所在可信网络开放；**不要把无认证 Ollama 暴露到公网**。
