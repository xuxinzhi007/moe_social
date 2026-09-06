#!/usr/bin/env bash
set -euo pipefail
CFG=/root/gowork/backend/config/config.yaml
python3 - <<'PY'
from pathlib import Path
p = Path("/root/gowork/backend/config/config.yaml")
text = p.read_text(encoding="utf-8")
old = 'memory_model: "qwen3:4b"'
new = 'memory_model: "qwen2.5:3b-instruct"'
if old not in text:
    raise SystemExit("memory_model pattern not found")
p.write_text(text.replace(old, new, 1), encoding="utf-8")
print("yaml updated")
PY
grep -n memory_model "$CFG"
cd /root/gowork/backend
docker compose -f docker-compose.binary.yml restart
sleep 3
curl -m 8 -sS http://127.0.0.1:8888/api/llm/config
echo
