#!/usr/bin/env python3
"""Remove unused imports from Go files (simple identifier scan)."""

from __future__ import annotations

import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]


def parse_imports(text: str) -> tuple[str, list[tuple[str, str | None]], str]:
    """Return (prefix before import, [(path, alias|None)], suffix after imports)."""
    m = re.search(r"(?ms)^import\s*\(\n(.*?)\n\)", text)
    if not m:
        return text, [], ""
    block = m.group(1)
    entries: list[tuple[str, str | None]] = []
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        alias = None
        path = line.strip('"')
        if " " in line:
            parts = line.split()
            if parts[1].startswith('"'):
                path = parts[1].strip('"')
            else:
                alias = parts[0]
                path = parts[1].strip('"')
        entries.append((path, alias))
    prefix = text[: m.start()]
    suffix = text[m.end() :]
    return prefix, entries, suffix


def used_in_body(body: str, path: str, alias: str | None) -> bool:
    default = path.split("/")[-1]
    if default.endswith(".go"):
        default = default[:-3]
    # common default aliases
    guesses = {alias, default}
    if path.startswith("backend/api/"):
        guesses.add(path.split("/")[2] + "v1")
    if alias:
        guesses.add(alias)
    if path == "context":
        guesses.add("context")
    if path == "encoding/json":
        guesses.add("json")
    if path == "strconv":
        guesses.add("strconv")
    if "gorm.io/gorm" in path:
        guesses.add("gorm")
    if path.endswith("/user") or "/biz/" in path:
        guesses.add(path.split("/")[-1] + "biz")
    if "/data/" in path:
        guesses.add(path.split("/")[-1] + "data")

    for g in guesses:
        if not g:
            continue
        if re.search(rf"\b{re.escape(g)}\.", body):
            return True
        if re.search(rf"\*{re.escape(g)}\.", body):
            return True
        if g == "context" and re.search(r"\bcontext\.", body):
            return True
        if g == "json" and re.search(r"\bjson\.", body):
            return True
        if g == "strconv" and re.search(r"\bstrconv\.", body):
            return True
        if g == "gorm" and re.search(r"\bgorm\.", body):
            return True
    # quoted import path used rarely
    if f'"{path}"' in body:
        return True
    return False


def format_imports(entries: list[tuple[str, str | None]]) -> str:
    if not entries:
        return ""
    if len(entries) == 1 and entries[0][1] is None and entries[0][0] in {
        "context",
        "encoding/json",
        "strconv",
    }:
        return f'import "{entries[0][0]}"\n'
    lines = ["import ("]
    for path, alias in entries:
        if alias:
            lines.append(f'\t{alias} "{path}"')
        else:
            lines.append(f'\t"{path}"')
    lines.append(")\n")
    return "\n".join(lines) + "\n"


def clean_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    prefix, entries, suffix = parse_imports(text)
    if not entries:
        return False
    kept = [(p, a) for p, a in entries if used_in_body(suffix, p, a)]
    if len(kept) == len(entries):
        return False
    new_text = prefix + format_imports(kept) + suffix.lstrip("\n")
    path.write_text(new_text, encoding="utf-8")
    return True


def main() -> None:
    root = BACKEND / "internal" / "service"
    changed = 0
    for _ in range(3):
        round_changed = 0
        for path in sorted(root.rglob("*.go")):
            if clean_file(path):
                round_changed += 1
                print(f"cleaned {path.relative_to(BACKEND)}")
        changed += round_changed
        if round_changed == 0:
            break
    print(f"total cleaned: {changed}")


if __name__ == "__main__":
    main()
