#!/usr/bin/env python3
"""Wrap user/app_tail.go passthrough returns with userv1/vipv1 ToMoe/FromMoe."""
from __future__ import annotations

import re
from pathlib import Path

VIP_TYPES = {
    "CreateVipOrder",
    "UpdateUserVip",
    "SyncUserVipStatus",
    "UpdateAutoRenew",
    "GetVipRecords",
    "GetUserActiveVipRecord",
}


def pkg_for(resp_type: str) -> str:
    for prefix in VIP_TYPES:
        if resp_type.startswith(prefix) or resp_type.replace("Req", "").replace("Resp", "") in VIP_TYPES:
            if resp_type.startswith(prefix):
                return "vipv1"
    for prefix in VIP_TYPES:
        if resp_type.startswith(prefix[:4]) or any(resp_type.startswith(p) for p in VIP_TYPES):
            pass
    base = resp_type.replace("Req", "").replace("Resp", "")
    if base in VIP_TYPES or any(resp_type.startswith(p) for p in VIP_TYPES):
        return "vipv1"
    if resp_type in (
        "CreateVipOrderReq", "CreateVipOrderResp",
        "UpdateUserVipReq", "UpdateUserVipResp",
        "SyncUserVipStatusReq", "SyncUserVipStatusResp",
        "UpdateAutoRenewReq", "UpdateAutoRenewResp",
        "GetVipRecordsReq", "GetVipRecordsResp",
        "GetUserActiveVipRecordReq", "GetUserActiveVipRecordResp",
    ):
        return "vipv1"
    if any(resp_type.startswith(p) for p in VIP_TYPES):
        return "vipv1"
    return "userv1"


def pkg_for_type(t: str) -> str:
    vip_names = (
        "CreateVipOrder", "UpdateUserVip", "SyncUserVipStatus", "UpdateAutoRenew",
        "GetVipRecords", "GetUserActiveVipRecord", "CheckUserVip", "GetUserVipStatus", "GetVipOrders",
    )
    for n in vip_names:
        if t.startswith(n):
            return "vipv1"
    return "userv1"


def wrap_return(line: str, resp_type: str, req_type: str | None) -> list[str]:
    m = re.match(r"^\s+return userbiz\.(\w+)\((.*)\)\s*$", line)
    if not m:
        return [line]
    func, args = m.group(1), m.group(2)
    pkg = pkg_for_type(resp_type)
    if req_type and re.search(r"\bin\b", args):
        args = re.sub(r"\bin\b", f"{pkg}.{req_type}ToMoe(in)", args)
    indent = "\t"
    return [
        f"{indent}out, err := userbiz.{func}({args})",
        f"{indent}if err != nil {{",
        f"{indent}\treturn nil, err",
        f"{indent}}}",
        f"{indent}return {pkg}.{resp_type}FromMoe(out), nil",
    ]


def process_file(path: Path) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith("func (s *AppService)"):
            sig = line
            m_resp = re.search(r"\(\*(\w+v1)\.(\w+), error\)", sig)
            if not m_resp:
                out.append(line)
                i += 1
                continue
            resp_type = m_resp.group(2)
            m_req = re.search(r"in \*\w+v1\.(\w+)", sig)
            req_type = m_req.group(1) if m_req else None
            out.append(line)
            i += 1
            while i < len(lines):
                ln = lines[i]
                if ln.startswith("func (s *AppService)"):
                    break
                if ln.strip().startswith("return userbiz."):
                    out.extend(wrap_return(ln, resp_type, req_type))
                    i += 1
                    continue
                out.append(ln)
                i += 1
            continue
        out.append(line)
        i += 1
    text = "\n".join(out) + "\n"
    if "vipv1" in text and 'vipv1 "backend/api/vip/v1"' not in text:
        text = text.replace(
            'userv1 "backend/api/user/v1"',
            'userv1 "backend/api/user/v1"\n\tvipv1 "backend/api/vip/v1"',
            1,
        )
    path.write_text(text, encoding="utf-8")
    print("wrapped", path)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2] / "internal/service/user"
    process_file(root / "app_tail.go")
