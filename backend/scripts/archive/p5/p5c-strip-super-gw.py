#!/usr/bin/env python3
"""P5-C: strip moe.SuperClient from api *gw packages."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "api" / "internal"
GWUTIL_IMPORT = '\t"backend/api/internal/gwutil"\n'

PACKAGES = [
    "postgw", "usergw", "commentgw", "communitygw", "checkinwg", "achievementgw",
    "giftgw", "llmgw", "chatgw", "landinggw", "aigw", "behaviorgw",
    "admingw", "vipadmingw", "moeadmingw",
]


def strip_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    orig = text

    text = re.sub(r"\n\tsuper\s+moe\.SuperClient\n", "\n", text)
    text = re.sub(
        r"func New\(([^,]+),\s*legacy moe\.SuperClient(?:,\s*kratos \*KratosHTTPClient)?\)",
        r"func New(\1)",
        text,
    )
    text = re.sub(
        r"func NewConfigured\(([^,]+),\s*legacy moe\.SuperClient\)",
        r"func NewConfigured(\1)",
        text,
    )
    text = re.sub(
        r"func NewConfigured\(([^,]+),\s*moeGRPC moepb\.MoeAdminClient,\s*legacy moe\.SuperClient\)",
        r"func NewConfigured(\1, moeGRPC moepb.MoeAdminClient)",
        text,
    )
    text = re.sub(
        r"func New\(([^,]+),\s*moeGRPC moepb\.MoeAdminClient,\s*legacy moe\.SuperClient,\s*kratos \*KratosHTTPClient\)",
        r"func New(\1, moeGRPC moepb.MoeAdminClient, kratos *KratosHTTPClient)",
        text,
    )
    text = re.sub(r"return &Gateway\{([^}]*),\s*super:\s*legacy,?\s*", r"return &Gateway{\1", text)
    text = re.sub(r"return &Gateway\{([^}]*),\s*super:\s*legacy\s*\}", r"return &Gateway{\1}", text)
    text = re.sub(r",\s*super:\s*legacy", "", text)

    text = re.sub(
        r"\tif g\.super != nil \{\n\t\treturn \"super\"\n\t\}\n",
        "",
        text,
    )
    text = re.sub(
        r" \|\| g\.super != nil",
        "",
        text,
    )
    text = re.sub(
        r"return g\.super\.[A-Za-z0-9]+\([^)]*\)(?:,\s*opts\.\.\.)?",
        "return nil, gwutil.ErrUnavailable",
        text,
    )
    text = re.sub(
        r"if g == nil \|\| g\.super == nil \{\n\t\treturn nil, gwutil\.ErrUnavailable\n\t\}\n",
        "if g == nil {\n\t\treturn nil, gwutil.ErrUnavailable\n\t}\n",
        text,
    )
    text = re.sub(
        r"if g\.super != nil \{\n\t\t[^\n]+\n\t\}\n",
        "",
        text,
    )

    if "gwutil.ErrUnavailable" in text and "gwutil" not in text.split("import (")[1].split(")")[0]:
        text = text.replace(
            "import (\n",
            "import (\n" + GWUTIL_IMPORT,
            1,
        )

    if text != orig:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> int:
    changed = 0
    for pkg in PACKAGES:
        d = ROOT / pkg
        if not d.is_dir():
            continue
        for go in d.glob("*.go"):
            if strip_file(go):
                print("updated", go.relative_to(ROOT.parent.parent))
                changed += 1
    print(f"done, {changed} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
