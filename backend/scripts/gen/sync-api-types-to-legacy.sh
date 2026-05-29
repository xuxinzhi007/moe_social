#!/usr/bin/env bash
# goctl gen-api 会在 api/internal/types 重生 types.go；生产已迁至 internal/legacy/types。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/api/internal/types/types.go"
DST="$ROOT/internal/legacy/types/types.go"

if [[ ! -f "$SRC" ]]; then
  echo "sync-api-types-to-legacy: no api/internal/types/types.go, skip"
  exit 0
fi

mkdir -p "$(dirname "$DST")"
cp "$SRC" "$DST"
rm -f "$SRC"
rmdir "$ROOT/api/internal/types" 2>/dev/null || true
echo "sync-api-types-to-legacy: copied types.go → internal/legacy/types/"
