#!/usr/bin/env python3
"""P5-E: Remove hybrid go-zero sources; keep codegen fixtures for gen-http-routes."""

from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTES_SRC = ROOT / "api/internal/handler/routes.go"
ROUTES_FIXTURE = ROOT / "scripts/gen/http-routes/fixtures/routes.go"

KEEP_UNDER_HANDLER = {
    "doc",
    "routes_stub.go",
    "README.md",
}


def is_hybrid_go(path: Path) -> bool:
    if path.suffix != ".go":
        return False
    try:
        head = path.read_text(encoding="utf-8", errors="replace")[:200]
    except OSError:
        return False
    return head.startswith("//go:build hybrid\n") or head.startswith("//go:build hybrid\r\n")


def should_delete(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    parts = rel.parts

    if is_hybrid_go(path):
        if parts[:3] == ("api", "internal", "handler"):
            name = parts[3] if len(parts) > 3 else ""
            if name in KEEP_UNDER_HANDLER or name == "doc":
                return False
            if len(parts) == 4 and parts[3] in KEEP_UNDER_HANDLER:
                return False
        return True

    if parts[:3] == ("api", "internal", "websocket"):
        return True

    return False


def archive_routes() -> None:
    if not ROUTES_SRC.is_file():
        if ROUTES_FIXTURE.is_file():
            print(f"routes fixture already present: {ROUTES_FIXTURE}")
            return
        raise SystemExit(f"missing routes source and fixture: {ROUTES_SRC}")

    ROUTES_FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROUTES_SRC, ROUTES_FIXTURE)
    print(f"archived routes → {ROUTES_FIXTURE}")


def main() -> None:
    archive_routes()

    deleted: list[str] = []
    for path in sorted(ROOT.rglob("*.go")):
        if "vendor" in path.parts:
            continue
        if should_delete(path) or is_hybrid_go(path):
            # handler/doc and routes_stub are protected above
            rel = path.relative_to(ROOT)
            if rel.parts[:3] == ("api", "internal", "handler"):
                if rel.parts[3:4] == ("doc",):
                    continue
                if rel.name in KEEP_UNDER_HANDLER:
                    continue
            path.unlink()
            deleted.append(str(rel))

    print(f"deleted {len(deleted)} hybrid/websocket .go files")
    for name in deleted[:20]:
        print(f"  - {name}")
    if len(deleted) > 20:
        print(f"  ... and {len(deleted) - 20} more")


if __name__ == "__main__":
    main()
