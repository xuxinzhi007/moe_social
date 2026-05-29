#!/usr/bin/env python3
"""P6-C: annotate api/defs/*.api with SSOT pointers for migrated HTTP routes."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFS = ROOT / "api" / "defs"

FILE_SSOT = {
    "admin.api": "api/admin/v1/admin_messages.proto",
    "ai_llm.api": "api/ai/v1 · api/llm/v1",
    "common.api": "api/defs/common.api (shared types only)",
    "landing.api": "api/landing/v1",
    "moe.api": "api/moe/v1 (tool execute — optional P6-6c)",
    "platform.api": "api/behavior/v1 · api/moehttp/platform_compat.go",
    "realtime.api": "api/chat/v1",
    "social.api": "api/post/v1 · api/comment/v1 · api/gift/v1 · api/community/v1 · …",
    "user.api": "api/user/v1/user_messages.proto",
    "vip.api": "api/vip/v1/vip_messages.proto · api/admin/v1 (admin VIP)",
}

HEADER = """// P6: Production HTTP SSOT → {ssot}
// Hybrid-only: @handler routes below feed make gen-api; runtime uses api/moehttp/*_compat.go.
// Do not add new routes here — use api/<domain>/v1/*.proto per new-api-kratos.md.
"""

ROUTE_RE = re.compile(r"^\s*(get|post|put|delete|patch)\s+(/api/\S+)", re.IGNORECASE)
HANDLER_RE = re.compile(r"^\s*@handler\s+(\S+)")


def annotate_file(path: Path) -> bool:
    name = path.name
    ssot = FILE_SSOT.get(name, "api/<domain>/v1")
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    if lines and lines[0].startswith("// P6: Production HTTP SSOT"):
        return False

    out: list[str] = []
    inserted_header = False
    pending_handler: str | None = None

    for line in lines:
        if not inserted_header and not line.lstrip().startswith("//"):
            out.append(HEADER.format(ssot=ssot))
            inserted_header = True

        hm = HANDLER_RE.match(line)
        if hm:
            pending_handler = hm.group(1)
            out.append(line)
            continue

        rm = ROUTE_RE.match(line)
        if rm and pending_handler:
            method, route = rm.group(1).lower(), rm.group(2)
            out.append(f"\t// P6 migrated → {ssot} ({method.upper()} {route})\n")
            pending_handler = None

        out.append(line)

    path.write_text("".join(out), encoding="utf-8")
    return True


def main() -> None:
    changed = 0
    for api in sorted(DEFS.glob("*.api")):
        if annotate_file(api):
            changed += 1
            print(f"annotated {api.name}")
    print(f"done: {changed} file(s) updated")


if __name__ == "__main__":
    main()
