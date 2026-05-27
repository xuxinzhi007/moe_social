#!/usr/bin/env bash
# 纯 Kratos 进度 80% 验收（Phase 0～4）
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/verify-kratos-60.sh

echo "== Phase 4: conf.proto + Wire =="
test -f internal/conf/moe/v1/pilot.proto
test -f internal/conf/moe/v1/pilot.pb.go
test -f internal/platform/moeconf/load.go
test -f internal/platform/moekratos/wire_gen.go
test -f internal/platform/moekratos/provider.go
grep -q 'pilot:' config/config.yaml
grep -q ':19031' config/config.yaml
bash scripts/gen-moe-conf.sh
go test ./internal/platform/moeconf/... -count=1

if [ "${MOE_KRATOS_LIVE:-}" = "1" ]; then
  curl -sf "http://127.0.0.1:19032/migration" | grep -q '"progress_percent":80'
fi

echo ""
echo "OK: pure kratos migration at 80% (phase 0-4)"
