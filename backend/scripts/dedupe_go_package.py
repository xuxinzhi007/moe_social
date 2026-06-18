#!/usr/bin/env python3
"""Remove duplicate package/import headers introduced by fix_split_imports."""

from __future__ import annotations

import re
from pathlib import Path

ROOTS = [
    Path(__file__).resolve().parents[1] / "internal" / "service",
    Path(__file__).resolve().parents[1] / "internal" / "server" / "protohttp",
]


def dedupe(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    matches = list(re.finditer(r"(?m)^package \w+", text))
    if len(matches) <= 1:
        return False

    # Keep from first doc comment before second package, or from second package
    second = matches[1].start()
    before = text[:second]
    doc = ""
    doc_m = re.search(r"(?ms)(^// Package .+?\n(?:^// .+\n)*)", before)
    if doc_m:
        doc = doc_m.group(1)
    rest = text[second:]
    # drop duplicate doc in rest if present
    rest = re.sub(r"(?ms)^// Package .+?\n(?:^// .+\n)*", "", rest, count=1)
    new_text = doc + rest.lstrip("\n")
    path.write_text(new_text, encoding="utf-8")
    return True


def main() -> None:
    for root in ROOTS:
        for path in root.rglob("*.go"):
            if dedupe(path):
                print(f"deduped {path}")


if __name__ == "__main__":
    main()
