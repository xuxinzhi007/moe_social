#!/usr/bin/env python3
"""Extract message definitions from rpc/defs/common.proto into api/<domain>/v1/*_messages.proto
and generate moe_bridge_gen.go with wire-compatible proto.Clone helpers.

Usage (from backend/):
  python scripts/gen/p6_extract_domain_proto.py admin
  python scripts/gen/p6_extract_domain_proto.py user
  python scripts/gen/p6_extract_domain_proto.py ai
  python scripts/gen/p6_extract_domain_proto.py llm
  python scripts/gen/p6_extract_domain_proto.py vip
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMON = ROOT / "rpc/defs/common.proto"
FRAGS = {
    "admin": ROOT / "rpc/defs/services/admin.rpcfrag",
    "user": ROOT / "rpc/defs/services/user.rpcfrag",
    "ai": ROOT / "rpc/defs/services/ai_llm.rpcfrag",
    "llm": ROOT / "rpc/defs/services/ai_llm.rpcfrag",
    "vip": ROOT / "rpc/defs/services/vip.rpcfrag",
}

# Seed types per domain (rpc method Req/Resp + shared types)
SEEDS = {
    "admin": None,  # all Admin* + RecordAdmin*
    "user": None,   # from user.rpcfrag
    "ai": {
        "ListAiResourceReq", "ListAiResourceResp", "ListPublicAiAgentsReq",
        "UpsertAiResourceReq", "UpsertAiResourceResp", "DeleteAiResourceReq", "DeleteAiResourceResp",
        "AiJsonResourceItem",
    },
    "llm": {
        "RecordLlmChatTurnReq", "RecordLlmChatTurnResp",
        "UpsertUserMemoryReq", "UpsertUserMemoryResp",
        "GetUserMemoriesReq", "GetUserMemoriesResp",
        "GetUserMemoryProfilesReq", "GetUserMemoryProfilesResp",
        "DeleteUserMemoryReq", "DeleteUserMemoryResp",
        "SubmitUserMemoryFeedbackReq", "SubmitUserMemoryFeedbackResp",
        "ListUserMemoryEmbeddingsReq", "ListUserMemoryEmbeddingsResp",
        "UpsertUserMemoryEmbeddingReq", "UpsertUserMemoryEmbeddingResp",
        "RebuildUserMemoryEmbeddingsReq", "RebuildUserMemoryEmbeddingsResp",
        "ListUserMemoryRelationsReq", "ListUserMemoryRelationsResp",
        "GetAiUserConfigReq", "GetAiUserConfigResp",
        "UpsertAiUserConfigReq", "UpsertAiUserConfigResp",
        "UserMemory", "UserMemoryProfile", "UserMemoryEmbedding", "UserMemoryRelation",
        "AiUserConfig",
    },
    "vip": {
        "UpdateUserVipReq", "UpdateUserVipResp", "GetVipPlansReq", "GetVipPlansResp",
        "GetVipPlanReq", "GetVipPlanResp", "CreateVipPlanReq", "CreateVipPlanResp",
        "CreateVipOrderReq", "CreateVipOrderResp", "GetVipOrdersReq", "GetVipOrdersResp",
        "GetVipRecordsReq", "GetVipRecordsResp", "GetUserActiveVipRecordReq", "GetUserActiveVipRecordResp",
        "GetUserVipStatusReq", "GetUserVipStatusResp", "CheckUserVipReq", "CheckUserVipResp",
        "UpdateAutoRenewReq", "UpdateAutoRenewResp", "SyncUserVipStatusReq", "SyncUserVipStatusResp",
        "VipPlan", "VipOrder", "VipRecord",
    },
}

PKG = {
    "admin": ("admin.v1", "adminv1", "admin"),
    "user": ("user.v1", "userv1", "user"),
    "ai": ("ai.v1", "aiv1", "ai"),
    "llm": ("llm.v1", "llmv1", "llm"),
    "vip": ("vip.v1", "vipv1", "vip"),
}


def parse_messages(text: str) -> dict[str, str]:
    parts = re.split(r"\n(?=message )", text)
    out: dict[str, str] = {}
    for p in parts:
        m = re.match(r"message (\w+)", p)
        if not m:
            continue
        name = m.group(1)
        out[name] = p.strip()
    return out


def field_type_refs(body: str) -> set[str]:
    refs: set[str] = set()
    for m in re.finditer(r"(?:repeated )?([A-Z][A-Za-z0-9_]*) ", body):
        t = m.group(1)
        if t in ("string", "int32", "int64", "uint32", "uint64", "bool", "float", "double", "bytes"):
            continue
        refs.add(t)
    return refs


def rpc_types_from_frag(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    names: set[str] = set()
    for m in re.finditer(r"rpc \w+\((\w+)\) returns \((\w+)\)", text):
        names.add(m.group(1))
        names.add(m.group(2))
    return names


def closure(seeds: set[str], messages: dict[str, str]) -> set[str]:
    seen: set[str] = set()
    stack = list(seeds)
    while stack:
        n = stack.pop()
        if n in seen or n not in messages:
            continue
        seen.add(n)
        for ref in field_type_refs(messages[n]):
            if ref not in seen:
                stack.append(ref)
    return seen


def admin_seeds(messages: dict[str, str]) -> set[str]:
    return {n for n in messages if n.startswith("Admin") or n.startswith("RecordAdmin")}


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: p6_extract_domain_proto.py <admin|user|ai|llm|vip>")
        sys.exit(1)
    domain = sys.argv[1]
    if domain not in PKG:
        print("unknown domain", domain)
        sys.exit(1)

    pkg, gopkg, folder = PKG[domain]
    common_text = COMMON.read_text(encoding="utf-8")
    messages = parse_messages(common_text)

    if domain == "admin":
        seed = admin_seeds(messages)
    elif SEEDS[domain] is None:
        seed = rpc_types_from_frag(FRAGS[domain])
    else:
        seed = set(SEEDS[domain])

    selected = closure(seed, messages)
    ordered = sorted(selected, key=lambda x: (not x.startswith("Admin"), x))

    out_dir = ROOT / "api" / folder / "v1"
    out_dir.mkdir(parents=True, exist_ok=True)
    proto_path = out_dir / f"{domain}_messages.proto"
    lines = [
        'syntax = "proto3";',
        f"package {pkg};",
        f'option go_package = "backend/api/{folder}/v1;{gopkg}";',
        "",
        f"// P6: extracted from rpc/defs/common.proto ({len(ordered)} messages)",
        "",
    ]
    for name in ordered:
        block = messages[name]
        lines.append(block)
        lines.append("")
    proto_path.write_text("\n".join(lines), encoding="utf-8")

    # bridge helpers
    bridge_path = out_dir / "moe_bridge_gen.go"
    bridge_lines = [
        f"package {gopkg}",
        "",
        "import (",
        '\t"backend/rpc/pb/moe"',
        "",
        '\t"google.golang.org/protobuf/proto"',
        ")",
        "",
        "func cloneTo[S, D proto.Message](src S, newDst func() D) D {",
        "	var zero D",
        "	if any(src) == nil {",
        "		return zero",
        "	}",
        "	dst := newDst()",
        "	b, err := proto.Marshal(src)",
        "	if err != nil {",
        "		return zero",
        "	}",
        "	if err := proto.Unmarshal(b, dst); err != nil {",
        "		return zero",
        "	}",
        "	return dst",
        "}",
        "",
    ]
    for name in ordered:
        bridge_lines.extend([
            f"func {name}FromMoe(in *moe.{name}) *{name} {{",
            f"\treturn cloneTo(in, func() *{name} {{ return &{name}{{}} }})",
            f"}}",
            "",
            f"func {name}ToMoe(in *{name}) *moe.{name} {{",
            f"\treturn cloneTo(in, func() *moe.{name} {{ return &moe.{name}{{}} }})",
            f"}}",
            "",
        ])
    bridge_path.write_text("\n".join(bridge_lines), encoding="utf-8")
    print(f"OK {domain}: {len(ordered)} messages -> {proto_path}")
    print(f"     bridge -> {bridge_path}")


if __name__ == "__main__":
    main()
