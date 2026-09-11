# 推理服务与记忆系统（SSOT）

> **推理（当前生效值）**：局域网 n100 小主机上的 **Ollama** `http://192.168.124.77:11434`，`api_style: ollama`，`memory_model: qwen2.5:3b-instruct`（`backend/config/config.yaml:89-94`）。  
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

`backend/config/config.yaml` 中的 `ollama.*` 仅作**读取兼容**（当前整段被注释，`:122-126`），新部署勿再配置。

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

## 遗留 API

- `POST /api/llm/agents`（Ollama modelfile）：仅当 `api_style=ollama`；llama-server 场景返回 400 说明。  
- `GET /api/llm/config` 同时返回 `llm_inference` 与 `ollama`（同内容，兼容旧 App）。
