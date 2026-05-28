#!/usr/bin/env python3
"""Add //go:build hybrid to legacy api/internal/handler/**/*.go (except doc/, routes*.go)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HANDLER = ROOT / "api" / "internal" / "handler"
SKIP_NAMES = {"routes.go", "routes_stub.go"}
SKIP_DIRS = {"doc"}

for path in sorted(HANDLER.rglob("*.go")):
    if path.parent.name in SKIP_DIRS or path.name in SKIP_NAMES:
        continue
    text = path.read_text(encoding="utf-8")
    if text.startswith("//go:build"):
        continue
    path.write_text("//go:build hybrid\n\n" + text, encoding="utf-8")
    print("tagged", path.relative_to(ROOT))
