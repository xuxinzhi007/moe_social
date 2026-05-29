#!/usr/bin/env python3
"""Replace httpx.Parse in api/moehttp with bindRequest(ctx, &req)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOEHTTP = ROOT / "api" / "moehttp"

for path in MOEHTTP.glob("*.go"):
    if path.name in ("bind.go", "handler_bridge.go", "native_bridge.go"):
        continue
    text = path.read_text(encoding="utf-8")
    if "httpx" not in text:
        continue
    text = text.replace("httpx.Parse(ctx.Request(), &", "bindRequest(ctx, &")
    text = text.replace("httpx.Parse(r, &", "bindRequest(ctx, &")  # rare
    lines = []
    for line in text.splitlines():
        if "github.com/zeromicro/go-zero/rest/httpx" in line:
            continue
        lines.append(line)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("updated", path.name)
