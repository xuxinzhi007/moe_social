#!/usr/bin/env python3
"""FS-8b/FS-9: 由 defs/common.proto + defs/services/*.rpcfrag 组装 rpc/moe.proto。"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RPC_DIR = ROOT / "rpc"
MOE_PROTO = RPC_DIR / "moe.proto"
DEFS_DIR = RPC_DIR / "defs"
SERVICES_DIR = DEFS_DIR / "services"

HEADER = """// FS-9: goctl RPC 入口（assemble 生成；编辑 RPC 请改 defs/services/<domain>.rpcfrag）
// message SSOT: defs/common.proto
syntax = "proto3";

package super;

option go_package = "backend/rpc/pb/moe";

import "defs/common.proto";

service Super {
"""


def main() -> int:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from fs8_rpc_domain import domain_order  # noqa: E402

    if not (DEFS_DIR / "common.proto").is_file():
        print("missing rpc/defs/common.proto — run fs8-split-super-proto first", file=sys.stderr)
        return 1

    parts = [HEADER]
    for dom in domain_order():
        frag = SERVICES_DIR / f"{dom}.rpcfrag"
        if not frag.is_file():
            continue
        text = frag.read_text(encoding="utf-8").strip()
        if not text:
            continue
        rpc_count = sum(1 for ln in text.splitlines() if ln.strip().startswith("rpc "))
        if rpc_count == 0:
            continue
        parts.append(f"\n  // --- domain: {dom} ({rpc_count} rpc) ---\n")
        for line in text.splitlines():
            if line.startswith("// FS-8b:") and "域 RPC" in line:
                continue
            if not line.strip():
                continue
            if line.strip().startswith("//") and "domain:" not in line:
                parts.append("  " + line.strip() + "\n")
            elif line.strip().startswith("rpc "):
                parts.append("  " + line.strip() + "\n")
            elif line.strip().startswith("rpc"):
                parts.append("  " + line.strip() + "\n")

    parts.append("}\n")
    MOE_PROTO.write_text("".join(parts), encoding="utf-8")
    legacy = RPC_DIR / "super.proto"
    if legacy.is_file():
        legacy.unlink()
    print(f"assembled {MOE_PROTO.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
