#!/usr/bin/env python3
"""FS-8: 将 api/moe.api（或 legacy super.api）拆为 api/defs/<domain>.api + common.api。"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API_DIR = ROOT / "api"
MOE_API = API_DIR / "moe.api"
LEGACY_SUPER_API = API_DIR / "super.api"
DEFS_DIR = API_DIR / "defs"
MANIFEST = Path(__file__).resolve().parent / "fs8-domain-groups.json"

HEADER_MOE = """// FS-9: goctl HTTP 入口（仅 import）；契约 SSOT 在 api/defs/*.api
syntax = "v1"

info (
\ttitle:   "Moe Social API"
\tdesc:    "Moe Social REST API (domain-sharded)"
\tauthor:  "Moe Social"
\temail:   "team@moe.social"
\tversion: "1.0.0"
)
"""

HEADER_COMMON = """// FS-8: 全站 HTTP 共享类型（各域 .api 通过 import 引用，禁止跨域复制 type）
syntax = "v1"
"""

HEADER_DOMAIN = """// FS-8: __DOMAIN__ 域路由（goctl group → api/internal/logic/<group>）
syntax = "v1"

import "common.api"
"""


def load_domain_groups() -> dict[str, list[str]]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    group_to_domain: dict[str, str] = {}
    for domain, groups in data.items():
        for g in groups:
            if g in group_to_domain:
                raise SystemExit(f"duplicate group {g!r} in manifest")
            group_to_domain[g] = domain
    return data, group_to_domain


def brace_balance_through(lines: list[str], start: int) -> int:
    """Return index after block starting at start (inclusive), using brace counting."""
    depth = 0
    started = False
    i = start
    while i < len(lines):
        for ch in lines[i]:
            if ch == "{":
                depth += 1
                started = True
            elif ch == "}":
                depth -= 1
                if started and depth == 0:
                    return i + 1
        i += 1
    raise ValueError(f"unbalanced braces from line {start + 1}")


def paren_balance_through(lines: list[str], start: int) -> int:
    """Return index after parenthesized block (e.g. info (...))."""
    depth = 0
    started = False
    i = start
    while i < len(lines):
        for ch in lines[i]:
            if ch == "(":
                depth += 1
                started = True
            elif ch == ")":
                depth -= 1
                if started and depth == 0:
                    return i + 1
        i += 1
    raise ValueError(f"unbalanced parens from line {start + 1}")


def parse_super_api(text: str) -> tuple[list[str], list[str], list[str]]:
    """Return (info_lines, type_blocks, server_blocks) as lists of joined line strings."""
    lines = text.splitlines()
    i = 0
    info_lines: list[str] = []
    type_blocks: list[str] = []
    server_blocks: list[str] = []

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("syntax ="):
            i += 1
            continue

        if stripped.startswith("info"):
            end = paren_balance_through(lines, i)
            info_lines = lines[i:end]
            i = end
            continue

        if stripped.startswith("type "):
            end = brace_balance_through(lines, i)
            block = "\n".join(lines[i:end]).strip()
            type_blocks.append(block)
            i = end
            continue

        if stripped.startswith("@server"):
            end = brace_balance_through(lines, i)
            block = "\n".join(lines[i:end]).strip()
            server_blocks.append(block)
            i = end
            continue

        if stripped.startswith("//") or stripped == "":
            i += 1
            continue

        if stripped.startswith("import "):
            i += 1
            continue

        raise SystemExit(f"unexpected line {i + 1}: {line!r}")

    return info_lines, type_blocks, server_blocks


def extract_group(server_block: str) -> str:
    m = re.search(r"group:\s*(\w+)", server_block)
    if not m:
        raise SystemExit(f"missing group in server block:\n{server_block[:200]}...")
    return m.group(1)


def main() -> int:
    entry = MOE_API if MOE_API.is_file() else LEGACY_SUPER_API
    if not entry.is_file():
        print(f"missing {MOE_API} (or legacy {LEGACY_SUPER_API})", file=sys.stderr)
        return 1

    domain_groups, group_to_domain = load_domain_groups()
    text = entry.read_text(encoding="utf-8")
    _, type_blocks, server_blocks = parse_super_api(text)

  # Assign servers to domains
    by_domain: dict[str, list[str]] = {d: [] for d in domain_groups}
    seen_groups: set[str] = set()

    for block in server_blocks:
        g = extract_group(block)
        if g in seen_groups:
            print(f"warning: duplicate @server group {g!r}", file=sys.stderr)
        seen_groups.add(g)
        domain = group_to_domain.get(g)
        if not domain:
            raise SystemExit(f"group {g!r} not in fs8-domain-groups.json — update manifest")
        by_domain[domain].append(block)

    for g in group_to_domain:
        if g not in seen_groups:
            print(f"warning: manifest group {g!r} not found in entry api", file=sys.stderr)

    DEFS_DIR.mkdir(parents=True, exist_ok=True)

    common_path = DEFS_DIR / "common.api"
    if not any(b.startswith("type BaseResp ") for b in type_blocks):
        raise SystemExit("BaseResp missing from parsed types — aborting split")

    common_body = HEADER_COMMON + "\n\n".join(type_blocks) + "\n"
    common_path.write_text(common_body, encoding="utf-8")

    import_lines = ['import "defs/common.api"']
    for domain in domain_groups:
        blocks = by_domain[domain]
        if not blocks:
            continue
        domain_path = DEFS_DIR / f"{domain}.api"
        body = HEADER_DOMAIN.replace("__DOMAIN__", domain) + "\n\n".join(blocks) + "\n"
        domain_path.write_text(body, encoding="utf-8")
        import_lines.append(f'import "defs/{domain}.api"')

    moe_body = HEADER_MOE + "\n".join(import_lines) + "\n"
    MOE_API.write_text(moe_body, encoding="utf-8")
    if LEGACY_SUPER_API.is_file():
        LEGACY_SUPER_API.unlink()

    print(f"FS-8 split OK: {len(type_blocks)} types → defs/common.api")
    for domain, blocks in by_domain.items():
        if blocks:
            print(f"  defs/{domain}.api: {len(blocks)} @server block(s)")
    print(f"  moe.api: {len(import_lines)} imports")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
