#!/usr/bin/env python3
"""Fix user_compat.go and checkin_compat admin section for P6 bridges."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

VIP_REQ = (
    "GetUserVipStatus", "CheckUserVip", "UpdateUserVip", "GetVipOrders",
    "CreateVipOrder", "SyncUserVipStatus", "UpdateAutoRenew", "GetVipRecords",
    "GetUserActiveVipRecord",
)


def pkg_for_type(name: str) -> str:
    for p in VIP_REQ:
        if name.startswith(p):
            return "vipv1"
    return "userv1"


def wrap_app_calls(text: str) -> str:
    def repl(m: re.Match) -> str:
        method, typ = m.group(1), m.group(2)
        return f"app.{method}(ctx, {pkg_for_type(typ)}.{typ}FromMoe(&moe.{typ}{{"
    text = re.sub(r"app\.(\w+)\(ctx, &moe\.(\w+)\{", repl, text)
    lines = text.splitlines()
    out: list[str] = []
    depth = 0
    for ln in lines:
        if "FromMoe(&moe." in ln:
            depth += 1
        if depth > 0 and re.match(r"^\s+\}\)\s*$", ln):
            ln = re.sub(r"\}\)\s*$", "}))", ln)
            depth -= 1
        out.append(ln)
    return "\n".join(out) + "\n"


def fix_user_compat() -> None:
    path = ROOT / "api/moehttp/user_compat.go"
    text = path.read_text(encoding="utf-8")
    if 'userv1 "backend/api/user/v1"' not in text:
        text = text.replace(
            'userapp "backend/internal/service/user"',
            'userv1 "backend/api/user/v1"\n\tvipv1 "backend/api/vip/v1"\n\tuserapp "backend/internal/service/user"',
            1,
        )
    text = wrap_app_calls(text)
    text = text.replace("userFromRPC(rpcResp.GetUser())", "userFromUserV1(rpcResp.GetUser())")
    text = text.replace("userFromRPC(rpcResp.User)", "userFromUserV1(rpcResp.User)")
    text = re.sub(
        r"userFromRPC\(([a-z])\)",
        r"userFromUserV1(\1)",
        text,
    )
    text = text.replace("userFromUserV1(v)", "userFromRPC(v)")  # friend views still moe
    text = text.replace("friendViewFromRPC(v)", "friendViewFromRPC(v)")
    # fix friendView - FromUser/ToUser may be userv1
    path.write_text(text, encoding="utf-8")
    print("user_compat ok")


def fix_user_convert() -> None:
    path = ROOT / "api/moehttp/user_convert.go"
    text = path.read_text(encoding="utf-8")
    if "userFromUserV1" not in text:
        text = text.replace(
            '"backend/rpc/pb/moe"',
            'userv1 "backend/api/user/v1"\n\t"backend/rpc/pb/moe"',
            1,
        )
        insert = """

func userFromUserV1(u *userv1.User) types.User {
	if u == nil {
		return types.User{}
	}
	return userFromRPC(userv1.UserToMoe(u))
}
"""
        text = text.replace("func userFromRPC(u *moe.User)", insert + "\nfunc userFromRPC(u *moe.User)", 1)
    path.write_text(text, encoding="utf-8")
    print("user_convert ok")


def fix_checkin_compat() -> None:
    path = ROOT / "api/moehttp/checkin_compat.go"
    text = path.read_text(encoding="utf-8")
    if 'adminv1 "backend/api/admin/v1"' not in text:
        text = text.replace(
            'adminapp "backend/internal/service/admin"',
            'adminv1 "backend/api/admin/v1"\n\tadminapp "backend/internal/service/admin"',
            1,
        )
    text = text.replace(
        "app.ListCheckInRewards(ctx, &moe.AdminListCheckInRewardsReq{})",
        "app.ListCheckInRewards(ctx, adminv1.AdminListCheckInRewardsReqFromMoe(&moe.AdminListCheckInRewardsReq{}))",
    )
    text = text.replace(
        "common.RpcAdminCheckInRewardToTypes(item)",
        "common.RpcAdminCheckInRewardToTypes(adminv1.AdminCheckInRewardItemToMoe(item))",
    )
    text = text.replace(
        "app.UpdateCheckInReward(ctx, &moe.AdminUpdateCheckInRewardReq{",
        "app.UpdateCheckInReward(ctx, adminv1.AdminUpdateCheckInRewardReqFromMoe(&moe.AdminUpdateCheckInRewardReq{",
    )
    text = text.replace(
        "common.RpcAdminCheckInRewardToTypes(rpcResp.GetItem())",
        "common.RpcAdminCheckInRewardToTypes(adminv1.AdminCheckInRewardItemToMoe(rpcResp.GetItem()))",
    )
    # close FromMoe for UpdateCheckInReward multiline
    text = text.replace(
        "\t\tUpdateExtraReward:     req.UpdateExtraReward,\n\t\t})",
        "\t\tUpdateExtraReward:     req.UpdateExtraReward,\n\t\t}))",
    )
    path.write_text(text, encoding="utf-8")
    print("checkin_compat ok")


if __name__ == "__main__":
    fix_user_convert()
    fix_user_compat()
    fix_checkin_compat()
