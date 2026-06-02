# 学习工作台集成说明

管理台 **学习工作台**（`/ops/app/learning`）连接记忆 RAG 健康检查与离线 LoRA 训练流水线。

## 架构

| 层 | 职责 |
|----|------|
| **Admin API** | `GET /api/admin/memories/health`、`POST /api/admin/memories/reindex`、`POST /api/admin/learning/export-dataset` |
| **moe-admin** | 四 Tab：健康 / 重建 / 导出 / 训练任务 |
| **Deploy Agent** | `learning_env_check`、`learning_train_lora` → `tools/character-finetune/*.sh` |
| **ollama_web** | 用户本机 clone 的 `finetune/`（`OLLAMA_WEB_FINETUNE_DIR`） |

**不**走 Ollama 导入；GGUF 注册在 `local_models.catalog` + llama-server。

## 记忆 vs 训练

- **user_memories + embedding**：事实检索（RAG），见 `backend/pkg/memory`。
- **LoRA**：人设/语气，导出 JSONL 后由 Python 训练，与记忆表无关。

## 操作步骤

1. 打开学习工作台 → **记忆健康**，确认 embedding 探针与索引覆盖率。
2. 对单用户 **向量重建**（需 `user_id`）。
3. **训练集导出**：填写 `user_id`、`agent_id`（`ai_user_configs.agents` 内 id），下载 JSONL。
4. **LoRA 训练**：Deploy Agent 运行 `learning_train_lora`，参数 `dataset_path` 为 JSONL 绝对路径。
5. 上游 merge → GGUF，写入 `backend/config/config.yaml` 的 `local_models.catalog`，重启 llama-server。

## 相关文件

- `backend/internal/biz/admin/memory_health.go`
- `backend/internal/biz/admin/memory_learning.go`
- `tools/character-finetune/README.md`
- `backend/deploy/runner/platform.go`（job 命令）

## OpenClaw 对齐

借鉴 MEMORY / daily / flush 的产品分层，不以 Markdown 为 SSOT；运行时仍以 DB + `pkg/memory` 为准。

## 两个「环境」不要混

| 按钮/探针 | 检查什么 | 不负责什么 |
|-----------|----------|------------|
| **记忆健康 → Embedding 探针** | llama-server 是否支持 `/v1/embeddings`、向量能否写入 | LoRA 训练 |
| **LoRA 训练 → 训练环境检查** | Python/torch、`OLLAMA_WEB_FINETUNE_DIR` 下 `train_lora.py` | 聊天推理、记忆 embedding |

Embedding 探针报 `501 … Start it with '--embeddings'` 时：聊天仍可用，但 **向量条数/索引覆盖率为空**、混合检索会退化为关键词。

## 记忆库列表为何重复（已修）

`daily_note:YYYY-MM-DD` 是 OpenClaw 式**工作日记**（每回合追加流水），只应注入 prompt，不应出现在 App「关于你的记忆」卡片列表。修复后：

- 列表/画像聚合会隐藏 `daily_note:*`
- 新写入的日记自动截断尾部约 2400 字符，避免无限变长

已有脏数据：管理台「记忆治理」删除含 `daily_note:` 的条目，或对该用户执行「向量重建」前清库。

## Flutter（App 侧 P1）

| 项 | 实现 |
|----|------|
| 注入可见性 | `AiMemoryStatusStrip` + 聊天页上回合注入/写入统计 |
| Bootstrap 预算 | `lib/services/memory_bootstrap_budget.dart` ↔ `ComposeBootstrap` |
| 本机提取模型 | `MemoryExtractLlmClient` / `MemoryAgentService` 优先当前聊天 model id |
