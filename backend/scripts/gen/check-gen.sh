#!/usr/bin/env bash
# Compare current sources and working-tree outputs, not git HEAD.
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/../.."
root=$PWD
work=$(mktemp -d "${TMPDIR:-/tmp}/moe-check-gen.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$work/generated"
bash scripts/gen/moe-proto.sh --output "$work/generated"

manifest() (
  cd "$1"
  {
    if [[ -d api ]]; then
      find api -name '*.pb.go' \( -type f -o -type l \)
    fi
    if [[ -e openapi.yaml || -L openapi.yaml ]]; then
      printf '%s\n' openapi.yaml
    fi
  } | sort
)
manifest "$work/generated" > "$work/expected.paths"
manifest "$root" > "$work/current.paths"
status=0
if ! diff -u "$work/current.paths" "$work/expected.paths"; then
  printf 'check-gen: generated paths differ (- extra, + missing in working tree)\n' >&2
  status=1
fi
while IFS= read -r file; do
  if [[ ! -f "$root/$file" ]] || ! cmp -s "$root/$file" "$work/generated/$file"; then
    printf 'check-gen: missing or stale output: %s\n' "$file" >&2
    status=1
  fi
done < "$work/expected.paths"
if [[ "$status" -ne 0 ]]; then
  printf 'check-gen: failed; working-tree outputs were not changed. Run make gen and review obsolete files.\n' >&2
  exit "$status"
fi
printf 'OK: check-gen (paths and bytes match current sources; working tree unchanged)\n'
