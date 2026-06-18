#!/usr/bin/env python3
"""Add shared import blocks from {domain}.go to split feature files."""

from __future__ import annotations

import re
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
SERVICE_ROOT = BACKEND / "internal" / "service"


def extract_import_block(text: str) -> str:
    m = re.search(r"(?ms)^import\s*\(\n.*?\n\)", text)
    if m:
        return m.group(0)
    m = re.search(r"^import .+\n", text, re.M)
    return m.group(0) if m else ""


def fix_domain(domain: str) -> None:
    core = SERVICE_ROOT / domain / f"{domain}.go"
    if not core.exists():
        return
    text = core.read_text(encoding="utf-8")
    pkg = re.search(r"^package (\w+)", text, re.M)
    if not pkg:
        return
    package = pkg.group(1)
    imports = extract_import_block(text)
    if not imports:
        return

    for path in SERVICE_ROOT.joinpath(domain).glob(f"{domain}_*.go"):
        body = path.read_text(encoding="utf-8")
        if imports in body:
            continue
        # strip existing bare package line and rebuild
        body = re.sub(r"^package \w+\n+", "", body)
        path.write_text(f"package {package}\n\n{imports}\n\n{body.lstrip()}", encoding="utf-8")
        print(f"fixed imports: {path.name}")


def main() -> None:
    for domain_dir in sorted(SERVICE_ROOT.iterdir()):
        if not domain_dir.is_dir():
            continue
        fix_domain(domain_dir.name)


if __name__ == "__main__":
    main()
