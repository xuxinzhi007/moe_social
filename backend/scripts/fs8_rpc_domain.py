"""FS-8b: RPC 方法名 → 域（供 split/assemble/verify 共用）。"""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

RULES_PATH = Path(__file__).resolve().parent / "fs8-rpc-domain-rules.json"


@lru_cache(maxsize=1)
def load_rules() -> dict:
    return json.loads(RULES_PATH.read_text(encoding="utf-8"))


def domain_order() -> list[str]:
    return list(load_rules()["domain_order"])


def domain_for_rpc(name: str) -> str:
    rules = load_rules()
    exact = rules.get("exact", {})
    for domain, names in exact.items():
        if name in names:
            return domain

  # Moe admin RPCs before generic Admin
    if name.startswith("Admin") and "Moe" in name:
        return "moe"
    if name.startswith("Moe"):
        return "moe"

    for domain, prefixes in rules.get("prefixes", {}).items():
        if domain == "admin":
            continue
        for p in prefixes:
            if name.startswith(p):
                return domain

    if name.startswith("Admin"):
        return "admin"

    for domain, subs in rules.get("contains", {}).items():
        for sub in subs:
            if sub in name:
                return domain

    return rules.get("default", "user")
