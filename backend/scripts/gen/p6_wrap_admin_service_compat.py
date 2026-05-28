#!/usr/bin/env python3
"""Safely bridge admin_service_compat.go only."""
from __future__ import annotations

import re
from pathlib import Path

PATH = Path(__file__).resolve().parents[2] / "api/moehttp/admin_service_compat.go"
PKG = "adminv1"

RPC_MAP = {
    "RpcAdminAccountToTypes": "AdminAccountItemToMoe",
    "RpcAdminAnnouncementToTypes": "AnnouncementToMoe",
    "RpcAdminGiftToTypes": "GiftToMoe",
    "RpcAdminUserToTypes": "UserToMoe",
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


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if f'{PKG} "backend/api/admin/v1"' not in text:
        text = text.replace(
            'adminapp "backend/internal/service/admin"',
            f'{PKG} "backend/api/admin/v1"\n\tadminapp "backend/internal/service/admin"',
            1,
        )

    text = re.sub(
        r"((?:app|svcCtx\.AdminApp)\.\w+)\(ctx, &moe\.(\w+)\{",
        rf"\1(ctx, {PKG}.\2FromMoe(&moe.\2{{",
        text,
    )

    # Close FromMoe call args: `		})` -> `		}))` when inside FromMoe block
    lines = text.splitlines()
    out: list[str] = []
    depth = 0
    for ln in lines:
        if "FromMoe(&moe." in ln:
            depth += 1
        if depth > 0 and ln.rstrip() == "\t\t})":
            ln = "\t\t}))"
            depth -= 1
        out.append(ln)
    text = "\n".join(out) + "\n"

    text = text.replace(
        "svcCtx.AdminApp.UpdateAccount(ctx, rpcReq)",
        f"svcCtx.AdminApp.UpdateAccount(ctx, {PKG}.AdminUpdateAccountReqFromMoe(rpcReq))",
    )

    for rpc_fn, to_moe in RPC_MAP.items():
        text = re.sub(
            rf"({re.escape(rpc_fn)}\()((?!{PKG}\.)[^)]+)\)",
            rf"\1({PKG}.{to_moe}(\2))",
            text,
        )

    PATH.write_text(text, encoding="utf-8")
    print("ok", PATH)


if __name__ == "__main__":
    main()
