#!/usr/bin/env bash
# OpenAPI uses the same pins, preflight and sorted inputs as make gen.
set -euo pipefail
exec bash "$(dirname "$0")/moe-proto.sh" --openapi-only "$@"
