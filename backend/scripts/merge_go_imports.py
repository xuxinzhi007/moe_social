#!/usr/bin/env python3
"""Merge multiple import blocks in Go files into one."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def merge_imports(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    blocks = list(re.finditer(r"(?ms)^import\s*(?:\(\n.*?\n\)|\"[^\"]+\")\n", text))
    if len(blocks) <= 1:
        return False

    entries: list[str] = []
    seen: set[str] = set()
    for b in blocks:
        block = b.group(0)
        inner = re.search(r"import\s*\((.*?)\)", block, re.S)
        if inner:
            for line in inner.group(1).splitlines():
                line = line.strip()
                if not line or line.startswith("//"):
                    continue
                if line not in seen:
                    seen.add(line)
                    entries.append(line)
        else:
            m = re.search(r'import "([^"]+)"', block)
            if m:
                line = f'"{m.group(1)}"'
                if line not in seen:
                    seen.add(line)
                    entries.append(line)

    first = blocks[0].start()
    last = blocks[-1].end()
    merged = "import (\n\t" + "\n\t".join(entries) + "\n)\n"
    new_text = text[:first] + merged + text[last:]
    path.write_text(new_text, encoding="utf-8")
    return True


def main() -> None:
    for path in ROOT.rglob("*.go"):
        if merge_imports(path):
            print(f"merged {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
