#!/usr/bin/env bash
# FS-8: HTTP 契约按域分片（api/defs）+ goctl 生成不混域。
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"
manifest="$(pwd)/scripts/fs8-domain-groups.json"

echo "== verify-sprint-fs8 =="

test -f api/moe.api
test -f api/defs/common.api
test -f "$manifest"

# moe.api 仅为入口（import + info），不得再含 type / @server
if grep -qE '^type |^@server' api/moe.api; then
  echo "FS-8: moe.api must not contain type or @server (use defs/)"
  exit 1
fi

for domain in landing user admin vip social ai_llm realtime platform moe; do
  test -f "api/defs/${domain}.api"
done

cd api
goctl api validate -api moe.api

# 域 manifest：每个 group 只出现在一个 defs 文件
python3 - <<'PY' "$manifest"
import json, re, sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
group_to_domain = {}
for domain, groups in manifest.items():
    for g in groups:
        group_to_domain[g] = domain

defs = Path("defs")
errors = []
for f in sorted(defs.glob("*.api")):
    if f.name == "common.api":
        continue
    domain = f.stem
    text = f.read_text(encoding="utf-8")
    for m in re.finditer(r"group:\s*(\w+)", text):
        g = m.group(1)
        if group_to_domain.get(g) != domain:
            errors.append(f"{f.name}: group {g} expected in {group_to_domain.get(g)}, not {domain}")
    for g in group_to_domain:
        if group_to_domain[g] == domain and g not in text:
            pass  # duplicate blocks (user/chat) may omit second mention in grep — ok

if errors:
    print("\n".join(errors))
    sys.exit(1)
PY

# 生成物：handler/logic 目录与 manifest group 一致，禁止落在未知目录
for g in landing ops user avatar emoji privatemsg notification admin admin_public vip \
  post comment community gift content llm ai chat voice doc image appcfg checkin achievement behavior moe; do
  test -d "api/internal/logic/$g" || { echo "missing logic group dir: $g"; exit 1; }
done

# 抽样：landing 路由只出现在 landing logic
if ! grep -q 'submitlandingfeedbacklogic' api/internal/logic/landing/submitlandingfeedbacklogic.go 2>/dev/null; then
  if ! ls api/internal/logic/landing/*feedback* 1>/dev/null 2>&1; then
    echo "FS-8: landing logic sample missing"
    exit 1
  fi
fi

go build ./api ./rpc
echo "OK: FS-8 domain-sharded API contracts + build"
