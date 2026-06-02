#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FINETUNE_DIR="${OLLAMA_WEB_FINETUNE_DIR:-}"
if [[ -z "$FINETUNE_DIR" ]]; then
  for c in "$HOME/ollama_web/finetune" "$ROOT/../ollama_web/finetune"; do
    if [[ -d "$c" ]]; then FINETUNE_DIR="$c"; break; fi
  done
fi
echo "workspace=$ROOT"
echo "OLLAMA_WEB_FINETUNE_DIR=${FINETUNE_DIR:-<not set>}"
command -v python3 >/dev/null || { echo "python3 missing"; exit 1; }
python3 -c "import torch; print('torch', torch.__version__)" 2>/dev/null || echo "WARN: torch not installed"
if [[ -n "${FINETUNE_DIR:-}" && -f "$FINETUNE_DIR/train_lora.py" ]]; then
  echo "OK: train_lora.py found"
else
  echo "WARN: set OLLAMA_WEB_FINETUNE_DIR to ollama_web/finetune"
  exit 1
fi
