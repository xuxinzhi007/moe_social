#!/usr/bin/env python3
"""FS-8b: 将 rpc/moe.proto（或 legacy super.proto）拆为 defs/common.proto + services/*.rpcfrag。"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RPC_DIR = ROOT / "rpc"
MOE_PROTO = RPC_DIR / "moe.proto"
LEGACY_SUPER_PROTO = RPC_DIR / "super.proto"
DEFS_DIR = RPC_DIR / "defs"
SERVICES_DIR = DEFS_DIR / "services"

HEADER_COMMON = """// FS-8b: 全站 RPC message（各域 rpcfrag 共用；禁止重复定义）
syntax = "proto3";

package super;

option go_package = "backend/rpc/pb/super";

"""

HEADER_MOE_PLACEHOLDER = """// placeholder — run fs8-assemble-super-proto.py
syntax = "proto3";
package super;
option go_package = "backend/rpc/pb/super";
import "defs/common.proto";
service Super {
"""


def brace_balance_through(lines: list[str], start: int, open_ch: str, close_ch: str) -> int:
    depth = 0
    started = False
    i = start
    while i < len(lines):
        for ch in lines[i]:
            if ch == open_ch:
                depth += 1
                started = True
            elif ch == close_ch:
                depth -= 1
                if started and depth == 0:
                    return i + 1
        i += 1
    raise ValueError(f"unbalanced {open_ch}{close_ch} from line {start + 1}")


def parse_proto(path: Path) -> tuple[list[str], list[str], list[str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    i = 0
    header: list[str] = []
    messages: list[str] = []
    rpc_lines: list[str] = []
    in_service = False
    service_depth = 0

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not in_service and (
            stripped.startswith("syntax")
            or stripped.startswith("package")
            or stripped.startswith("option ")
            or stripped.startswith("// DEPRECATED")
            or (stripped.startswith("//") and "message" not in stripped and "rpc" not in stripped)
        ):
            if stripped.startswith("message ") or stripped.startswith("service "):
                pass
            else:
                i += 1
                continue

        if stripped.startswith("message "):
            end = brace_balance_through(lines, i, "{", "}")
            messages.append("\n".join(lines[i:end]))
            i = end
            continue

        if stripped.startswith("service Super"):
            in_service = True
            i += 1
            service_depth = 1
            continue

        if in_service:
            if stripped == "}" and service_depth == 1:
                in_service = False
                i += 1
                continue
            if stripped.startswith("rpc "):
                rpc_lines.append(line)
            elif stripped.startswith("//"):
                rpc_lines.append(line)
            i += 1
            continue

        i += 1

    return header, messages, rpc_lines


def main() -> int:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from fs8_rpc_domain import domain_for_rpc, domain_order  # noqa: E402

    entry = MOE_PROTO if MOE_PROTO.is_file() else LEGACY_SUPER_PROTO
    if not entry.is_file():
        print(f"missing {MOE_PROTO} (or legacy {LEGACY_SUPER_PROTO})", file=sys.stderr)
        return 1

    _, messages, rpc_lines = parse_proto(entry)
    if not messages:
        raise SystemExit("no messages parsed — abort")
    if not rpc_lines:
        raise SystemExit("no rpc lines parsed — abort")

    DEFS_DIR.mkdir(parents=True, exist_ok=True)
    SERVICES_DIR.mkdir(parents=True, exist_ok=True)

    common = HEADER_COMMON + "\n\n".join(messages) + "\n"
    (DEFS_DIR / "common.proto").write_text(common, encoding="utf-8")

    by_domain: dict[str, list[str]] = {d: [] for d in domain_order()}
    seen_rpc: set[str] = set()

    for line in rpc_lines:
        m = re.match(r"^\s*rpc\s+(\w+)\s*\(", line)
        if m:
            name = m.group(1)
            if name in seen_rpc:
                print(f"warning: duplicate rpc {name}", file=sys.stderr)
            seen_rpc.add(name)
            dom = domain_for_rpc(name)
            by_domain.setdefault(dom, []).append(line)
        else:
            if by_domain:
                last_dom = domain_order()[-1]
                for d in reversed(domain_order()):
                    if by_domain[d]:
                        last_dom = d
                        break
                by_domain[last_dom].append(line)

    for dom in domain_order():
        frag = SERVICES_DIR / f"{dom}.rpcfrag"
        body = by_domain.get(dom, [])
        header = f"// FS-8b: {dom} 域 RPC（编入 service Super）\n"
        frag.write_text(header + "\n".join(body) + ("\n" if body else ""), encoding="utf-8")

    MOE_PROTO.write_text(HEADER_MOE_PLACEHOLDER + "\n}\n", encoding="utf-8")
    if LEGACY_SUPER_PROTO.is_file():
        LEGACY_SUPER_PROTO.unlink()

    print(f"FS-8b split OK: {len(messages)} messages → defs/common.proto")
    for dom in domain_order():
        n = len([ln for ln in by_domain.get(dom, []) if ln.strip().startswith("rpc ")])
        if n:
            print(f"  defs/services/{dom}.rpcfrag: {n} rpc")
    print(f"  total rpc: {len(seen_rpc)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
