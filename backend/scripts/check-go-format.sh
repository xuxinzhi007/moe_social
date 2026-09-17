#!/usr/bin/env bash
set -euo pipefail

root="${1:-$(dirname "$0")/..}"
cd "$root"
files=()
# 归档目录包含不参与构建的历史代码模板，不能作为 Go 源码解析。
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find . -type d \( -path './scripts/archive' -o -name vendor -o -name .git \) -prune -o -type f -name '*.go' -print0)

if [ "${#files[@]}" -eq 0 ]; then
  echo "No Go source files found" >&2
  exit 1
fi
unformatted="$(gofmt -l "${files[@]}")"
if [ -n "$unformatted" ]; then
  printf 'Go files require gofmt:\n%s\n' "$unformatted" >&2
  exit 1
fi
