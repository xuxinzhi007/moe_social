#!/usr/bin/env python3
"""Rebuild import blocks from identifier usage in Go service files."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "internal" / "service"

# prefix -> (alias, path)
KNOWN = [
    ("postv1", "backend/api/post/v1"),
    ("postbiz", "backend/internal/biz/post"),
    ("postdata", "backend/internal/data/post"),
    ("mediabiz", "backend/internal/biz/media"),
    ("chatv1", "backend/api/chat/v1"),
    ("chatbiz", "backend/internal/biz/chat"),
    ("chatdata", "backend/internal/data/chat"),
    ("landingv1", "backend/api/landing/v1"),
    ("landingbiz", "backend/internal/biz/landing"),
    ("landingdata", "backend/internal/data/landing"),
    ("giftv1", "backend/api/gift/v1"),
    ("giftbiz", "backend/internal/biz/gift"),
    ("giftdata", "backend/internal/data/gift"),
    ("notifyv1", "backend/api/notify/v1"),
    ("notifybiz", "backend/internal/biz/notify"),
    ("notifydata", "backend/internal/data/notify"),
    ("checkinv1", "backend/api/checkin/v1"),
    ("checkinbiz", "backend/internal/biz/checkin"),
    ("checkindata", "backend/internal/data/checkin"),
    ("behaviorv1", "backend/api/behavior/v1"),
    ("behaviorbiz", "backend/internal/biz/behavior"),
    ("behaviordata", "backend/internal/data/behavior"),
    ("communityv1", "backend/api/community/v1"),
    ("communitybiz", "backend/internal/biz/community"),
    ("communitydata", "backend/internal/data/community"),
    ("commentv1", "backend/api/comment/v1"),
    ("commentbiz", "backend/internal/biz/comment"),
    ("commentdata", "backend/internal/data/comment"),
    ("aiv1", "backend/api/ai/v1"),
    ("aibiz", "backend/internal/biz/ai"),
    ("aidata", "backend/internal/data/ai"),
    ("voicebiz", "backend/internal/biz/voice"),
    ("mediav1", "backend/api/media/v1"),
    ("mediabiz", "backend/internal/biz/media"),
    ("mediadata", "backend/internal/data/media"),
    ("adminv1", "backend/api/admin/v1"),
    ("platformv1", "backend/api/platform/v1"),
    ("adminbiz", "backend/internal/biz/admin"),
    ("admindata", "backend/internal/data/admin"),
    ("communitydata", "backend/internal/data/community"),
    ("chatbiz", "backend/internal/biz/chat"),
    ("notifybiz", "backend/internal/biz/notify"),
    ("userbiz", "backend/internal/biz/user"),
    ("userdata", "backend/internal/data/user"),
    ("userv1", "backend/api/user/v1"),
    ("vipv1", "backend/api/vip/v1"),
    ("llmv1", "backend/api/llm/v1"),
    ("llmbiz", "backend/internal/biz/llm"),
    ("llmdata", "backend/internal/data/llm"),
    ("emojibiz", "backend/internal/biz/emoji"),
    ("vipbiz", "backend/internal/biz/vip"),
    ("vipdata", "backend/internal/data/vip"),
    ("achievementv1", "backend/api/achievement/v1"),
    ("achievementbiz", "backend/internal/biz/achievement"),
    ("achievementdata", "backend/internal/data/achievement"),
]

STDLIB = {
    "context": "context",
    "json": "encoding/json",
    "strconv": "strconv",
    "grpc": "google.golang.org/grpc",
}


def rebuild(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    pkg = re.search(r"^package (\w+)", text, re.M)
    if not pkg:
        return False

    comments = ""
    cm = re.match(r"(?ms)((?:^//[^\n]*\n)*)", text)
    if cm and cm.group(1).strip():
        comments = cm.group(1)

    body = text[len(comments) :]
    body = re.sub(r"^package \w+\s*\n", "", body, count=1)
    body = re.sub(r"(?ms)^import\s*(?:\(\n.*?\n\)|\"[^\"]+\")\n+", "", body)

    lines: list[str] = []
    seen_paths: set[str] = set()

    if re.search(r"\bcontext\.", body):
        lines.append('"context"')
        seen_paths.add("context")
    if re.search(r"\bjson\.", body):
        lines.append('"encoding/json"')
        seen_paths.add("encoding/json")
    if re.search(r"\bstrconv\.", body):
        lines.append('"strconv"')
        seen_paths.add("strconv")
    if re.search(r"\bgrpc\.", body):
        lines.append('"google.golang.org/grpc"')
        seen_paths.add("google.golang.org/grpc")
    if re.search(r"\bgorm\.", body):
        lines.append('"gorm.io/gorm"')
        seen_paths.add("gorm.io/gorm")
    if re.search(r"\butils\.", body):
        lines.append('"backend/utils"')
        seen_paths.add("backend/utils")
    if re.search(r"\bmodel\.", body):
        lines.append('"backend/model"')
        seen_paths.add("backend/model")
    if "socialhook." in body:
        lines.append('"backend/internal/platform/socialhook"')
        seen_paths.add("backend/internal/platform/socialhook")
    if "achievement." in body:
        lines.append('"backend/pkg/achievement"')
        seen_paths.add("backend/pkg/achievement")

    for alias, imp in KNOWN:
        if re.search(rf"\b{re.escape(alias)}\.", body) and imp not in seen_paths:
            lines.append(f'{alias} "{imp}"')
            seen_paths.add(imp)

    if not lines:
        return False

    imp = "import (\n\t" + "\n\t".join(lines) + "\n)\n"
    new_text = comments + f"package {pkg.group(1)}\n\n{imp}\n" + body.lstrip()
    if new_text == text:
        return False
    path.write_text(new_text, encoding="utf-8")
    return True


def main() -> None:
    n = 0
    for path in sorted(ROOT.rglob("*.go")):
        if rebuild(path):
            print(path.relative_to(ROOT.parent.parent))
            n += 1
    print(f"rebuilt {n} files")


if __name__ == "__main__":
    main()
