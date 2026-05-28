#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WS = ROOT / "api" / "internal" / "websocket"
for path in WS.glob("*.go"):
    text = path.read_text(encoding="utf-8")
    if text.startswith("//go:build"):
        continue
    path.write_text("//go:build hybrid\n\n" + text, encoding="utf-8")
    print("tagged", path.name)
