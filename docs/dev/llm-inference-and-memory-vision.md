# 推理服务与记忆系统（SSOT）

> **推理**：本机 **llama-server**（OpenAI 兼容，`llm_inference.base_url`）。  
> **记忆**：**数据库**为长期存储；**单次 prompt** 为工作上下文（受 n_ctx 限制）。

## 配置

| 键 | 说明 |
|----|------|
| `llm_inference.base_url` | 如 `http://127.0.0.1:6633` |
| `llm_inference.api_style` | `openai`（默认） |
| `llm_inference.memory_model` | 记忆提取/总结用模型 |
| go-zero `etc/super.yaml` | 字段名 `LLMInference`（与 `Ollama` 旧键已统一） |

`backend/config/config.yaml` 中的 `ollama.*` 仅作**读取兼容**，新部署勿再配置。

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

## 遗留 API

- `POST /api/llm/agents`（Ollama modelfile）：仅当 `api_style=ollama`；llama-server 场景返回 400 说明。  
- `GET /api/llm/config` 同时返回 `llm_inference` 与 `ollama`（同内容，兼容旧 App）。
