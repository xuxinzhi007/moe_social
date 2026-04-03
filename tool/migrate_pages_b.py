#!/usr/bin/env python3
"""One-shot migration: move screens under lib/pages/<domain>/. Run from repo root."""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

# (source relative to lib/, dest relative to lib/)
MOVES: list[tuple[str, str]] = [
    # auth
    ("login_page.dart", "pages/auth/login_page.dart"),
    ("register_page.dart", "pages/auth/register_page.dart"),
    ("forgot_password_page.dart", "pages/auth/forgot_password_page.dart"),
    ("verify_code_page.dart", "pages/auth/verify_code_page.dart"),
    ("reset_password_page.dart", "pages/auth/reset_password_page.dart"),
    # feed
    ("create_post_page.dart", "pages/feed/create_post_page.dart"),
    ("comments_page.dart", "pages/feed/comments_page.dart"),
    ("topic_posts_page.dart", "pages/feed/topic_posts_page.dart"),
    ("pages/home_page.dart", "pages/feed/home_page.dart"),
    # profile
    ("profile_page.dart", "pages/profile/profile_page.dart"),
    ("edit_profile_page.dart", "pages/profile/edit_profile_page.dart"),
    ("user_profile_page.dart", "pages/profile/user_profile_page.dart"),
    ("following_page.dart", "pages/profile/following_page.dart"),
    ("followers_page.dart", "pages/profile/followers_page.dart"),
    ("friends_page.dart", "pages/profile/friends_page.dart"),
    ("memory_timeline_page.dart", "pages/profile/memory_timeline_page.dart"),
    # commerce
    ("vip_center_page.dart", "pages/commerce/vip_center_page.dart"),
    ("vip_purchase_page.dart", "pages/commerce/vip_purchase_page.dart"),
    ("vip_orders_page.dart", "pages/commerce/vip_orders_page.dart"),
    ("vip_history_page.dart", "pages/commerce/vip_history_page.dart"),
    ("wallet_page.dart", "pages/commerce/wallet_page.dart"),
    ("recharge_page.dart", "pages/commerce/recharge_page.dart"),
    ("gacha_page.dart", "pages/commerce/gacha_page.dart"),
    ("inventory_page.dart", "pages/commerce/inventory_page.dart"),
    # chat
    ("direct_chat_page.dart", "pages/chat/direct_chat_page.dart"),
    ("voice_call_page.dart", "pages/chat/voice_call_page.dart"),
    ("voice_call_receiving_page.dart", "pages/chat/voice_call_receiving_page.dart"),
    ("voice_call_initiation_page.dart", "pages/chat/voice_call_initiation_page.dart"),
    # settings / notifications
    ("settings_page.dart", "pages/settings/settings_page.dart"),
    ("notification_center_page.dart", "pages/notifications/notification_center_page.dart"),
    # discover
    ("pages/discover_page.dart", "pages/discover/discover_page.dart"),
    ("pages/match_page.dart", "pages/discover/match_page.dart"),
    # checkin / level
    ("pages/checkin_page.dart", "pages/checkin/checkin_page.dart"),
    ("pages/user_level_page.dart", "pages/checkin/user_level_page.dart"),
    # gallery
    ("gallery/cloud_gallery_page.dart", "pages/gallery/cloud_gallery_page.dart"),
    ("gallery/cloud_image_viewer_page.dart", "pages/gallery/cloud_image_viewer_page.dart"),
    # autoglm UI (service stays in lib/autoglm/)
    ("autoglm/autoglm_page.dart", "pages/autoglm/autoglm_page.dart"),
    ("pages/autoglm_config_page.dart", "pages/autoglm/autoglm_config_page.dart"),
    # unused entry screens — keep for future wiring
    ("ollama_chat_page.dart", "pages/ai/ollama_chat_page.dart"),
    ("demo_features_page.dart", "pages/demo/demo_features_page.dart"),
]

def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def move_file(src: Path, dst: Path) -> None:
    if not src.exists():
        raise FileNotFoundError(src)
    ensure_parent(dst)
    shutil.move(str(src), str(dst))


def main() -> None:
    for rel_src, rel_dst in MOVES:
        move_file(LIB / rel_src, LIB / rel_dst)

    # Remove empty gallery dir if possible
    gal = LIB / "gallery"
    if gal.exists() and not any(gal.iterdir()):
        gal.rmdir()

    print("Moves done. Run fix_imports / flutter analyze next.")


if __name__ == "__main__":
    main()
