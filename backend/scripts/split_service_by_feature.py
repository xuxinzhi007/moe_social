#!/usr/bin/env python3
"""Split internal/service/<domain>/service.go into {domain}_{feature}.go files."""

from __future__ import annotations

import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
SERVICE_ROOT = BACKEND / "internal" / "service"

# method_name -> output file suffix (without domain prefix)
ADMIN_GROUPS: dict[str, str] = {
    "GrowthStats": "dashboard",
    "SchemaCatalog": "dashboard",
    "ReadRuntimeConfig": "dashboard",
    "RuntimeOverview": "dashboard",
    "Dashboard": "dashboard",
    "AnalyticsOverview": "dashboard",
    "AdminLogin": "login",
    "AdminBootstrapAccount": "login",
    "RecordAuditLog": "audit",
    "BroadcastNotification": "notification",
    "SendNotification": "notification",
    "ListAnnouncements": "announcement",
    "GetAnnouncement": "announcement",
    "CreateAnnouncement": "announcement",
    "UpdateAnnouncement": "announcement",
    "PublishAnnouncement": "announcement",
    "ListPublishedAnnouncements": "announcement",
    "GetPublishedAnnouncement": "announcement",
    "DeleteAnnouncement": "announcement",
    "ListAuditLogs": "audit",
    "AdminListGifts": "gift",
    "AdminGetGift": "gift",
    "AdminCreateGift": "gift",
    "AdminUpdateGift": "gift",
    "AdminDeleteGift": "gift",
    "AdminBootstrapGifts": "gift",
    "AdminDedupeGifts": "gift",
    "ListUsers": "user",
    "UpdateUser": "user",
    "GetUser": "user",
    "GetUserProfile": "user",
    "ListAchievements": "achievement",
    "UpdateAchievement": "achievement",
    "BootstrapAchievements": "achievement",
    "ListMenus": "menu",
    "UpsertMenu": "menu",
    "DeleteMenu": "menu",
    "BootstrapMenus": "menu",
    "ListAiChatSessions": "aichat",
    "ListAiChatMessages": "aichat",
    "ExportAiChatMessages": "aichat",
    "ListTopicTags": "tag",
    "CreateTopicTag": "tag",
    "UpdateTopicTag": "tag",
    "DeleteTopicTag": "tag",
    "AdminBootstrapTopicTags": "tag",
    "ListTagDictionary": "tag",
    "CreateTagDictionary": "tag",
    "UpdateTagDictionary": "tag",
    "DeleteTagDictionary": "tag",
    "ListAiAgents": "ai_agent",
    "DeleteAiAgent": "ai_agent",
    "ListFollows": "moderation",
    "DeleteFollow": "moderation",
    "ListPosts": "moderation",
    "DeletePost": "moderation",
    "ListComments": "moderation",
    "DeleteComment": "moderation",
    "ListGroups": "moderation",
    "DeleteGroup": "moderation",
    "ListFriendRequests": "moderation",
    "ListPostReports": "moderation",
    "ListMemories": "memory",
    "DeleteMemory": "memory",
    "GetMemoryStats": "memory",
    "GetMemoryHealth": "memory",
    "RebuildMemoryEmbeddings": "memory",
    "ExportLearningDataset": "memory",
    "ListAccounts": "account",
    "CreateAccount": "account",
    "UpdateAccount": "account",
    "DeleteAccount": "account",
    "ListLevelConfigs": "level",
    "UpdateLevelConfig": "level",
    "BootstrapLevels": "level",
    "ListCheckInRewards": "checkin",
    "UpdateCheckInReward": "checkin",
    "ListVipOrders": "order",
    "ListGiftPurchaseOrders": "order",
}

DOMAIN_GROUPS: dict[str, dict[str, str]] = {
    "post": {
        "MoeSearchPosts": "read",
        "GetPost": "read",
        "GetPostHandDraw": "read",
        "GetPosts": "read",
        "CreatePost": "write",
        "UpdatePost": "write",
        "DeletePost": "write",
        "LikePost": "interaction",
        "ReportPost": "interaction",
    },
    "chat": {
        "SendPrivateMessage": "message",
        "ListPrivateMessages": "message",
        "ListPrivateConversations": "message",
        "PushNotification": "push",
        "PushBatchNotification": "push",
        "BroadcastPushNotification": "push",
    },
    "landing": {
        "Submit": "feedback",
        "List": "feedback",
    },
    "gift": {
        "GetGifts": "catalog",
        "GetGift": "catalog",
        "SendGift": "transaction",
        "PurchaseGift": "transaction",
        "GetGiftRecords": "transaction",
        "GetGiftPurchaseOrders": "transaction",
    },
    "notify": {
        "GetNotifications": "inbox",
        "GetUnreadCount": "inbox",
        "ReadNotification": "inbox",
        "ReadAllNotifications": "inbox",
        "Broadcast": "send",
        "SendToUser": "send",
    },
    "checkin": {
        "GetCheckInStatus": "checkin",
        "CheckIn": "checkin",
        "GetCheckInHistory": "checkin",
        "GetExpLogs": "level",
        "GetUserLevel": "level",
    },
    "behavior": {
        "TrackEvents": "track",
    },
    "community": {
        "GetGroups": "group",
        "GetGroup": "group",
        "GetUserGroups": "group",
        "GetGroupMembers": "group",
        "GetGroupPosts": "group",
        "CreateGroup": "group",
        "JoinGroup": "group",
        "LeaveGroup": "group",
        "DeleteGroup": "group",
        "UpdateGroup": "group",
        "CreateGroupPost": "group_post",
    },
    "comment": {
        "GetPostComments": "comment",
        "CreateComment": "comment",
        "LikeComment": "comment",
    },
    "ai": {
        "ListAiProviders": "list",
        "ListAiAgents": "list",
        "ListAiLorebooks": "list",
        "ListPublicAiAgents": "list",
        "UpsertAiProvider": "write",
        "UpsertAiAgent": "write",
        "UpsertAiLorebook": "write",
        "DeleteAiProvider": "write",
        "DeleteAiAgent": "write",
        "DeleteAiLorebook": "write",
    },
    "voice": {
        "VoiceCall": "call",
        "VoiceAnswer": "call",
        "VoiceCancel": "call",
        "VoiceReject": "call",
        "GetRtcToken": "rtc",
    },
    "media": {
        "ListImages": "image",
        "DeleteImage": "image",
        "OpenImage": "image",
        "UploadImage": "image",
    },
    "admin": ADMIN_GROUPS,
}

RENAME_ONLY = [
    "achievement",
    "appcfg",
    "content",
]


def split_go_file(domain: str, groups: dict[str, str]) -> None:
    src = SERVICE_ROOT / domain / "service.go"
    if not src.exists():
        print(f"skip {domain}: no service.go")
        return

    text = src.read_text(encoding="utf-8")
    pkg_match = re.search(r"^package\s+(\w+)", text, re.M)
    if not pkg_match:
        raise SystemExit(f"no package in {src}")
    package = pkg_match.group(1)

    # imports + types until first method on AppService
    method_re = re.compile(
        r"^((?://[^\n]*\n)*)func \(s \*AppService\) (\w+)\(",
        re.M,
    )
    matches = list(method_re.finditer(text))
    if not matches:
        # whole file becomes {domain}.go
        dest = SERVICE_ROOT / domain / f"{domain}.go"
        dest.write_text(text, encoding="utf-8")
        src.unlink()
        print(f"{domain}: renamed -> {dest.name}")
        return

    header_end = matches[0].start()
    header = text[:header_end].rstrip() + "\n"

    imports = extract_import_block(header)
    import_block = f"\n{imports}\n\n" if imports else "\n"

    buckets: dict[str, list[str]] = {}
    for i, m in enumerate(matches):
        name = m.group(2)
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        chunk = text[start:end].rstrip() + "\n"
        suffix = groups.get(name)
        if suffix is None:
            header += "\n" + chunk
            continue
        buckets.setdefault(suffix, []).append(chunk)

    core_path = SERVICE_ROOT / domain / f"{domain}.go"
    core_path.write_text(header.rstrip() + "\n", encoding="utf-8")

    for suffix, chunks in sorted(buckets.items()):
        body = f"package {package}{import_block}" + "\n".join(chunks)
        out = SERVICE_ROOT / domain / f"{domain}_{suffix}.go"
        out.write_text(body, encoding="utf-8")
        print(f"{domain}: wrote {out.name} ({len(chunks)} methods)")

    src.unlink()
    print(f"{domain}: removed service.go")


def rename_only(domain: str) -> None:
    src = SERVICE_ROOT / domain / "service.go"
    if not src.exists():
        return
    dest = SERVICE_ROOT / domain / f"{domain}.go"
    src.rename(dest)
    print(f"{domain}: renamed -> {dest.name}")


def main() -> None:
    for domain in RENAME_ONLY:
        rename_only(domain)

    for domain, groups in DOMAIN_GROUPS.items():
        split_go_file(domain, groups)

    print("done")


if __name__ == "__main__":
    main()
