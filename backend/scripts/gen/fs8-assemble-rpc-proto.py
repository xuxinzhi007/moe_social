#!/usr/bin/env python3
"""P5/D4 Phase-4: rpc/pb/moe 已退役；保留占位 moe.proto，不再 assemble common.proto。"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOE_PROTO = ROOT / "rpc" / "moe.proto"

RETIRED = """// RETIRED (D4 Phase-4): Super RPC 与 rpc/pb/moe 生成链已退役。
// 契约 SSOT：api/<domain>/v1/*.proto + google.api.http
// 历史 message 归档：scripts/archive/rpc-defs/common.proto
syntax = "proto3";

package super;

option go_package = "backend/rpc/pb/moe";

"""


def main() -> int:
    MOE_PROTO.write_text(RETIRED, encoding="utf-8")
    print(f"rpc/pb/moe retired; wrote placeholder {MOE_PROTO.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
