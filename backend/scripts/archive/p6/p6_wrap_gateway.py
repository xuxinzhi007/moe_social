#!/usr/bin/env python3
"""Wrap gateway passthrough: g.local.Method(ctx, in) -> domain v1 FromMoe/ToMoe."""
from __future__ import annotations

import re
import sys
from pathlib import Path

DOMAIN_PKG = {
    "user": ("userv1", 'userv1 "backend/api/user/v1"', "vipv1", 'vipv1 "backend/api/vip/v1"'),
    "admin": ("adminv1", 'adminv1 "backend/api/admin/v1"', None, None),
    "llm": ("llmv1", 'llmv1 "backend/api/llm/v1"', None, None),
}

VIP_PREFIXES = (
    "GetUserVipStatus", "GetVipOrders", "CheckUserVip", "CreateVipOrder",
    "UpdateUserVip", "SyncUserVipStatus", "UpdateAutoRenew", "GetVipRecords",
    "GetUserActiveVipRecord",
)


def pkg_for_type(name: str, domain: str) -> str:
    if domain == "user":
        for p in VIP_PREFIXES:
            if name.startswith(p):
                return "vipv1"
        return "userv1"
    return DOMAIN_PKG[domain][0]


def ensure_imports(text: str, domain: str) -> str:
    pkg, imp, vip_pkg, vip_imp = DOMAIN_PKG[domain]
    if imp.split()[0] not in text:
        text = text.replace(
            '"backend/rpc/pb/moe"',
            imp + "\n\t\"backend/rpc/pb/moe\"",
            1,
        )
    if vip_imp and vip_imp.split()[0] not in text:
        text = text.replace(
            imp,
            imp + "\n\t" + vip_imp,
            1,
        )
    return text


def wrap_gateway(path: Path, domain: str) -> None:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(
            r"func \(g \*Gateway\) (\w+)\(ctx context\.Context, in \*moe\.(\w+),",
            line,
        )
        if m:
            gw_method, req_type = m.group(1), m.group(2)
            resp_type = re.sub(r"Req$", "Resp", req_type)
            if resp_type == req_type:
                resp_type = req_type + "Resp"  # fallback
            pkg = pkg_for_type(req_type, domain)
            out.append(line)
            i += 1
            while i < len(lines):
                ln = lines[i]
                if ln.startswith("func (g *Gateway)"):
                    break
                mret = re.match(
                    r"^(\s+)return g\.local\.(\w+)\(ctx, in\)\s*$",
                    ln,
                )
                if mret:
                    indent, local_method = mret.group(1), mret.group(2)
                    out.append(f"{indent}out, err := g.local.{local_method}(ctx, {pkg}.{req_type}FromMoe(in))")
                    out.append(f"{indent}if err != nil {{")
                    out.append(f"{indent}\treturn nil, err")
                    out.append(f"{indent}}}")
                    out.append(f"{indent}return {pkg}.{resp_type}ToMoe(out), nil")
                    i += 1
                    continue
                out.append(ln)
                i += 1
            continue
        out.append(line)
        i += 1
    text = "\n".join(out) + "\n"
    text = ensure_imports(text, domain)
    path.write_text(text, encoding="utf-8")
    print("wrapped", path)


if __name__ == "__main__":
    domain = sys.argv[1]
    for p in sys.argv[2:]:
        wrap_gateway(Path(p), domain)
