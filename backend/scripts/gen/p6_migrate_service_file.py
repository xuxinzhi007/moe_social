#!/usr/bin/env python3
"""Migrate AppService: moe request/response signatures -> domain v1 + FromMoe on struct returns."""
from __future__ import annotations

import re
import sys
from pathlib import Path

CFG = {
    "user": ("userv1", 'userv1 "backend/api/user/v1"'),
    "admin": ("adminv1", 'adminv1 "backend/api/admin/v1"'),
}


def migrate(domain: str, path: Path) -> None:
    pkg, imp = CFG[domain]
    text = path.read_text(encoding="utf-8")
    if imp.split()[0] not in text:
        text = text.replace(
            '"backend/rpc/pb/moe"',
            imp + "\n\t\"backend/rpc/pb/moe\"",
            1,
        )

    # Wrap struct returns before renaming types in body
    text = re.sub(
        r"return (&moe\.(\w+)\{)",
        rf"return {pkg}.\2FromMoe(\1",
        text,
    )

    # Method signatures only
    def sig_repl(line: str) -> str:
        if line.strip().startswith("func (s *AppService)"):
            return re.sub(r"\*moe\.(\w+)", rf"*{pkg}.\1", line)
        return line

    text = "\n".join(sig_repl(ln) for ln in text.splitlines()) + "\n"
    path.write_text(text, encoding="utf-8")
    print("migrated", path)


if __name__ == "__main__":
    migrate(sys.argv[1], Path(sys.argv[2]))
