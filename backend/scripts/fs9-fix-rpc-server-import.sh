#!/usr/bin/env bash
# goctl 对 moe.proto 可能漏掉 pb/super import；生成后补齐。
set -euo pipefail
f="rpc/internal/server/superserver.go"
[ -f "$f" ] || exit 0
if grep -q 'backend/rpc/pb/super' "$f"; then
  exit 0
fi
python3 - <<'PY'
from pathlib import Path
p = Path("rpc/internal/server/superserver.go")
text = p.read_text(encoding="utf-8")
if "backend/rpc/pb/super" in text:
    raise SystemExit(0)
lines = text.splitlines()
out = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.strip() == "import (":
        out.append(line)
        i += 1
        while i < len(lines) and lines[i].strip() != ")":
            if "backend/api/moe/v1" in lines[i]:
                i += 1
                continue
            out.append(lines[i])
            i += 1
        out.append('\t"backend/rpc/pb/super"')
        out.append(lines[i])  # closing )
        i += 1
        continue
    out.append(line)
    i += 1
p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("fs9-fix-rpc-server-import: added backend/rpc/pb/super")
PY
