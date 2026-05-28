#!/usr/bin/env bash
# Fail if any *Gateway method returns super without a g.local branch in the same function.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
bad=0
while IFS= read -r line; do
  echo "GW super-only: $line"
  bad=1
done < <(
  for f in api/internal/*gw/*.go; do
    awk '
      /^func \(g \*Gateway\)/ { fn=1; name=$0; haslocal=0; hassuper=0 }
      fn && /g\.local/ { haslocal=1 }
      fn && /return g\.super\./ { hassuper=1 }
      fn && /^}$/ {
        if (fn && hassuper && !haslocal && name !~ /Super\(\)/) print FILENAME ": " name
        fn=0
      }
    ' "$f"
  done
)
if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "OK: all Gateway RPC methods have local-first branch"
