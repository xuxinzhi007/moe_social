#!/usr/bin/env bash
# gen-api 前提示：P3 后 handler 已直调 GW/biz，goctl 可能覆盖 handler。
set -euo pipefail
echo "gen-api: goctl 将更新 api/internal/handler、types、routes.go"
echo "  · P3 已完成：logic 层已退役；gen 后自动 prune-api-logic-retired.sh"
echo "  · 警告：goctl 可能把 handler 还原为 logic 委托 — 改 defs 后请 diff handler/ 并从 git 恢复已迁移文件"
echo "  · 业务改 compat：优先 api/moehttp/*_compat.go + internal/service/biz"
echo "  · 完成后自动 make gen-http-routes"
if [ "${MOE_SKIP_GEN_API_WARN:-}" = "1" ]; then
  exit 0
fi
echo "  · 跳过本提示: MOE_SKIP_GEN_API_WARN=1 make gen-api"
