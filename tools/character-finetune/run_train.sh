#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DATASET=""
OUTPUT=""
FINETUNE_DIR="${OLLAMA_WEB_FINETUNE_DIR:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dataset) DATASET="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --finetune-dir) FINETUNE_DIR="$2"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done
if [[ -z "$FINETUNE_DIR" ]]; then
  for c in "$HOME/ollama_web/finetune" "$ROOT/../ollama_web/finetune"; do
    [[ -d "$c" ]] && FINETUNE_DIR="$c" && break
  done
fi
[[ -n "$FINETUNE_DIR" && -f "$FINETUNE_DIR/train_lora.py" ]] || { echo "finetune dir missing"; exit 1; }
[[ -n "$DATASET" && -f "$DATASET" ]] || { echo "dataset required (--dataset path.jsonl)"; exit 1; }
OUT="${OUTPUT:-$ROOT/backend/data/learning_runs/$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT"
cd "$FINETUNE_DIR"
echo "Training with dataset=$DATASET output=$OUT"
python3 train_lora.py --data "$DATASET" --output "$OUT" "$@"
echo "Done. Merge LoRA and register GGUF in local_models.catalog."
