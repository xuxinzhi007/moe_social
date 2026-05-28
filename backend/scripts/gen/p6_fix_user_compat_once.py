#!/usr/bin/env python3
"""Wrap user_compat.go app calls with userv1/vipv1 FromMoe (safe close)."""
from pathlib import Path
import re

VIP = (
    "GetUserVipStatus",
    "CheckUserVip",
    "UpdateUserVip",
    "GetVipOrders",
    "CreateVipOrder",
    "SyncUserVipStatus",
    "UpdateAutoRenew",
    "GetVipRecords",
    "GetUserActiveVipRecord",
)


def pkg(name: str) -> str:
    return "vipv1" if any(name.startswith(p) for p in VIP) else "userv1"


def brace_delta(s: str) -> int:
    return s.count("{") - s.count("}")


def close_frommoe_paren(lines: list[str], start: int) -> None:
    """Ensure app.FromMoe(&moe.{...}) ends with ))."""
    line = lines[start]
    if "FromMoe(&moe." not in line:
        return
    d = brace_delta(line)
    if d == 0:
        # single-line struct
        s = line.rstrip()
        if s.endswith("})") and not s.endswith("}))"):
            lines[start] = s + ")"
        return
    i = start + 1
    while i < len(lines) and d > 0:
        d += brace_delta(lines[i])
        i += 1
    close_i = i - 1
    if close_i > start and re.match(r"^\s+\}\)\s*$", lines[close_i]):
        lines[close_i] = re.sub(r"\}\)\s*$", "}))", lines[close_i])


def main() -> None:
    p = Path(__file__).resolve().parents[2] / "api" / "moehttp" / "user_compat.go"
    t = p.read_text(encoding="utf-8")

    if "userv1 " not in t and 'userv1 "' not in t:
        t = t.replace(
            'userapp "backend/internal/service/user"',
            'userv1 "backend/api/user/v1"\n\tvipv1 "backend/api/vip/v1"\n\tuserapp "backend/internal/service/user"',
        )

    def repl(m: re.Match) -> str:
        mname, rname = m.group(1), m.group(2)
        return f"app.{mname}(ctx, {pkg(rname)}.{rname}FromMoe(&moe.{rname}{{"

    t = re.sub(r"app\.(\w+)\(ctx, &moe\.(\w+)\{", repl, t)
    lines = t.splitlines()

    for i, ln in enumerate(lines):
        if re.search(r"app\.\w+\(ctx, (?:userv1|vipv1)\.\w+FromMoe", ln):
            close_frommoe_paren(lines, i)

    t = "\n".join(lines) + "\n"
    t = t.replace("userFromRPC(rpcResp.GetUser())", "userFromUserV1(rpcResp.GetUser())")
    t = t.replace("userFromRPC(rpcResp.User)", "userFromUserV1(rpcResp.User)")
    t = re.sub(
        r"users = append\(users, userFromRPC\(u\)\)",
        "users = append(users, userFromUserV1(u))",
        t,
    )
    t = re.sub(
        r"out = append\(out, userFromRPC\(u\)\)",
        "out = append(out, userFromUserV1(u))",
        t,
    )
    p.write_text(t, encoding="utf-8")
    print("patched", p)


if __name__ == "__main__":
    main()
