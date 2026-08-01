#!/usr/bin/env python3
"""
将单张 PNG 对齐到 Moe Avatar 分层 sheet 模板（本地批量 · 可选）。

SSOT: assets/pet/config/avatar_layer_template.json
文档: docs/dev/pet-avatar-layer-template.md

用法（占位 · 待接 Pillow）:
  python scripts/pet/align_layer_to_template.py \\
    --input path/to/part.png \\
    --layer top \\
    --anim idle \\
    --output layers/slots/top_custom_idle.png

Fooocus 等 AI 出图 → 本脚本/ admin 对齐 → 校验 paintRect → 导出 pack。
Go 后端仅负责 P4 发布存储，不做像素合成。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TEMPLATE_PATH = REPO_ROOT / "assets" / "pet" / "config" / "avatar_layer_template.json"


def load_template() -> dict:
    with TEMPLATE_PATH.open(encoding="utf-8") as f:
        return json.load(f)


def main() -> int:
    parser = argparse.ArgumentParser(description="Align layer PNG to Moe avatar grid template")
    parser.add_argument("--input", required=True, help="Source PNG (e.g. Fooocus output)")
    parser.add_argument("--layer", required=True, help="Layer key: top|bottom|shoes|hat|body|...")
    parser.add_argument("--anim", choices=["walk", "idle"], default="idle")
    parser.add_argument("--output", required=True, help="Output sheet path")
    args = parser.parse_args()

    tpl = load_template()
    rules = tpl.get("layerRules", {})
    if args.layer not in rules:
        print(f"unknown layer: {args.layer}", file=sys.stderr)
        return 1

    cell = tpl["cellSize"]
    grid = tpl["animations"][args.anim]
    w, h = grid["cols"] * cell, grid["rows"] * cell
    rule = rules[args.layer]

    print(f"template: {tpl['templateId']}")
    print(f"target sheet: {w}x{h} ({grid['cols']}x{grid['rows']} @ cell {cell})")
    print(f"paintRect: {rule.get('paintRect')} — {rule.get('hint', '')}")
    print("TODO: implement Pillow align + alpha trim + paintRect validate")
    print(f"would write: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
