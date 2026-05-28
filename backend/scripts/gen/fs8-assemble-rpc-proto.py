#!/usr/bin/env python3
"""P5: 组装 rpc/moe.proto（仅 message SSOT；不再生成 service Super）。"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RPC_DIR = ROOT / "rpc"
MOE_PROTO = RPC_DIR / "moe.proto"
DEFS_DIR = RPC_DIR / "defs"

# P5-B: Super 服务已退役；RPC 契约见 api/<domain>/v1/*.proto
HEADER = """// P5: message-only（assemble 生成；勿恢复 service Super）
// message SSOT: defs/common.proto
// 域 gRPC：api/*/v1/*.proto · 历史 rpc 片段：defs/services/*.rpcfrag（归档，不参与 assemble）
syntax = "proto3";

package super;

option go_package = "backend/rpc/pb/moe";

import "defs/common.proto";

"""


def main() -> int:
    if not (DEFS_DIR / "common.proto").is_file():
        print("missing rpc/defs/common.proto", file=sys.stderr)
        return 1

    MOE_PROTO.write_text(HEADER, encoding="utf-8")
    legacy = RPC_DIR / "super.proto"
    if legacy.is_file():
        legacy.unlink()
    print(f"assembled {MOE_PROTO.relative_to(ROOT)} (messages-only, no Super service)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
