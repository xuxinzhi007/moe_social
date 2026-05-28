#!/usr/bin/env bash
# gen-api 前提示：会覆盖 goctl 产物，不会批量覆盖已有 logic 实现。
set -euo pipefail
echo "gen-api: goctl 将更新 api/internal/handler、types、routes.go"
echo "  · 业务逻辑写在 api/internal/logic/<group>/*logic.go（已有文件通常保留）"
echo "  · 完成后自动 make gen-http-routes → api/moehttp/routes_*_gen.go"
if [ "${MOE_SKIP_GEN_API_WARN:-}" = "1" ]; then
  exit 0
fi
echo "  · 跳过本提示: MOE_SKIP_GEN_API_WARN=1 make gen-api"
