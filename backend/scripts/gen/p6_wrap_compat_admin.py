#!/usr/bin/env python3
"""Wrap moehttp admin compat: app.*(&moe.*) -> adminv1.*FromMoe; Rpc*ToTypes(x) -> ToMoe(x)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "api/moehttp"
PKG = "adminv1"

RPC_TO_MOE = {
    "RpcAdminAccountToTypes": "AdminAccountItemToMoe",
    "RpcAdminGrowthStatsToTypes": "AdminGrowthStatsToMoe",
    "RpcAdminGiftToTypes": "GiftToMoe",
    "RpcAdminUserToTypes": "UserToMoe",
    "RpcAdminAnnouncementToTypes": "AnnouncementToMoe",
    "RpcAdminAchievementToTypes": "AchievementToMoe",
    "RpcAdminCommentToTypes": "CommentToMoe",
    "RpcAdminPostToTypes": "PostToMoe",
    "RpcAdminFollowToTypes": "FollowToMoe",
    "RpcAdminGroupToTypes": "GroupToMoe",
    "RpcAdminTagDictionaryToTypes": "TagDictionaryEntryToMoe",
    "RpcAdminTopicTagToTypes": "TopicTagToMoe",
    "RpcAdminVipPlanToTypes": "VipPlanToMoe",
    "RpcAdminLevelConfigToTypes": "LevelConfigToMoe",
    "RpcAdminCheckInRewardToTypes": "CheckInRewardToMoe",
    "RpcAdminAiAgentToTypes": "AiAgentItemToMoe",
    "RpcAdminAuditLogToTypes": "AuditLogItemToMoe",
    "RpcAdminFriendRequestToTypes": "FriendRequestItemToMoe",
    "RpcAdminPostReportToTypes": "PostReportItemToMoe",
    "RpcAdminVipOrderToTypes": "VipOrderItemToMoe",
    "RpcAdminGiftPurchaseOrderToTypes": "GiftPurchaseOrderItemToMoe",
}


def ensure_import(text: str) -> str:
    imp = f'{PKG} "backend/api/admin/v1"'
    if imp.split()[0] in text:
        return text
    return text.replace(
        '"backend/rpc/pb/moe"',
        imp + '\n\t"backend/rpc/pb/moe"',
        1,
    )


def wrap_app_calls(text: str) -> str:
    # app.Method(ctx, &moe.Type{ -> FromMoe
    def repl(m: re.Match) -> str:
        return f"{m.group(1)}{PKG}.{m.group(2)}FromMoe(&moe.{m.group(2)}{m.group(3)}"

    text = re.sub(
        r"((?:app|svcCtx\.AdminApp)\.\w+\([^,]+,\s*)&moe\.(\w+)(\{)",
        repl,
        text,
    )
    # Fix double-close: FromMoe(&moe.X{...})  needs extra )
    # Count lines ending with `})` that should be `}))` after FromMoe - heuristic: after FromMoe block
    lines = text.splitlines()
    out = []
    pending_close = 0
    for ln in lines:
        if "FromMoe(&moe." in ln:
            pending_close += 1
        if pending_close > 0 and re.search(r"^\s*\}\)\s*$", ln):
            ln = ln.replace("})", "}))", 1)
            pending_close -= 1
        out.append(ln)
    return "\n".join(out)


def wrap_rpc_to_types(text: str) -> str:
    for rpc_fn, to_moe in RPC_TO_MOE.items():
        text = re.sub(
            rf"({re.escape(rpc_fn)}\()([^)]+)\)",
            rf"\1({PKG}.{to_moe}(\2))",
            text,
        )
    return text


def process(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if "adminapp" not in text and "AdminApp" not in text:
        return
    text = ensure_import(text)
    text = wrap_app_calls(text)
    text = wrap_rpc_to_types(text)
    path.write_text(text + ("\n" if not text.endswith("\n") else ""), encoding="utf-8")
    print("patched", path)


def main() -> None:
    for p in sorted(ROOT.glob("admin*.go")):
        process(p)


if __name__ == "__main__":
    main()
