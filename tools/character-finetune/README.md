# Character finetune (LoRA → GGUF)

Offline LoRA training wrapper for **moe-admin 学习工作台**. Uses scripts from [ollama_web/finetune](https://github.com/xuxinzhi007/ollama_web) when available — **not** Ollama import.

## Setup

1. Clone ollama_web (or set `OLLAMA_WEB_FINETUNE_DIR`):

```bash
export OLLAMA_WEB_FINETUNE_DIR=~/ollama_web/finetune
```

2. Python env with `torch`, `transformers`, `peft` (see upstream `requirements.txt`).

## Scripts

| Script | Purpose |
|--------|---------|
| `env_check.sh` | Deploy job `learning_env_check` |
| `run_train.sh` | Deploy job `learning_train_lora` |

## After training

Merge LoRA → GGUF per upstream `merge_and_convert.py`, then register in `backend/config/config.yaml` under `local_models.catalog`.

## Admin flow

1. **学习工作台** → export dataset (JSONL).
2. Run `learning_train_lora` job with `dataset_path` pointing at exported file.
3. Copy GGUF to `local_models` path and reload llama-server.
