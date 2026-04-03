#!/usr/bin/env python3
"""Fix relative imports after pages/ migration. Run from repo root."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"


def fix_content(path: Path, text: str) -> str:
    rel = path.relative_to(LIB)
    parts = rel.parts
    if len(parts) < 2:
        return text

    # --- lib/pages/<domain>/<file>.dart (two segments under pages) ---
    if len(parts) == 3 and parts[0] == "pages":
        domain = parts[1]
        # These folders already used ../../ to lib; only fix wrong single-segment imports.
        if domain == "game":
            text = text.replace(
                "import '../../gacha_page.dart'",
                "import '../../commerce/gacha_page.dart'",
            )
            return text

        if domain == "ai":
            text = re.sub(
                r"import 'services/", "import '../../services/", text
            )
            text = re.sub(
                r"import 'models/", "import '../../models/", text
            )
            text = re.sub(
                r"import 'widgets/", "import '../../widgets/", text
            )
            return text

        # Default: one extra .. for former lib/ or pages/ children
        repls = [
            ("import 'auth_service.dart'", "import '../../auth_service.dart'"),
            ("import 'services/", "import '../../services/"),
            ("import 'models/", "import '../../models/"),
            ("import 'widgets/", "import '../../widgets/"),
            ("import 'providers/", "import '../../providers/"),
            ("import 'utils/", "import '../../utils/"),
            ("import 'config/", "import '../../config/"),
        ]
        for a, b in repls:
            text = text.replace(a, b)

        # Was under lib/pages/*.dart → now pages/<sub>/*.dart
        bump = [
            ("import '../auth_service.dart'", "import '../../auth_service.dart'"),
            ("import '../services/", "import '../../services/"),
            ("import '../models/", "import '../../models/"),
            ("import '../widgets/", "import '../../widgets/"),
            ("import '../providers/", "import '../../providers/"),
            ("import '../utils/", "import '../../utils/"),
            ("import '../config/", "import '../../config/"),
        ]
        for a, b in bump:
            text = text.replace(a, b)

        if domain == "discover":
            text = text.replace(
                "import 'ai/", "import '../ai/"
            ).replace("import 'game/", "import '../game/")

        if domain == "profile":
            text = text.replace(
                "import 'autoglm/autoglm_page.dart'",
                "import '../autoglm/autoglm_page.dart'",
            )
            text = text.replace(
                "import 'autoglm/autoglm_service.dart'",
                "import '../../autoglm/autoglm_service.dart'",
            )
            text = text.replace(
                "import 'wallet_page.dart'",
                "import '../commerce/wallet_page.dart'",
            )
            text = text.replace(
                "import 'gallery/cloud_gallery_page.dart'",
                "import '../gallery/cloud_gallery_page.dart'",
            )
            text = text.replace(
                "import 'pages/checkin_page.dart'",
                "import '../checkin/checkin_page.dart'",
            )
            text = text.replace(
                "import 'pages/user_level_page.dart'",
                "import '../checkin/user_level_page.dart'",
            )

        if domain == "feed":
            text = text.replace(
                "import '../gallery/", "import '../gallery/"
            )  # no-op; keep ../gallery from pages/feed

        if domain == "commerce":
            text = text.replace(
                "import 'package:moe_social/recharge_page.dart'",
                "import 'package:moe_social/pages/commerce/recharge_page.dart'",
            )
            text = text.replace(
                "import 'inventory_page.dart'", "import 'inventory_page.dart'"
            )
            text = text.replace(
                "import 'recharge_page.dart'", "import 'recharge_page.dart'"
            )
            text = text.replace(
                "import 'gacha_page.dart'", "import 'gacha_page.dart'"
            )
            text = text.replace(
                "import 'vip_purchase_page.dart'", "import 'vip_purchase_page.dart'"
            )

        if domain == "autoglm":
            text = text.replace(
                "import '../widgets/", "import '../../widgets/"
            )
            text = text.replace(
                "import '../services/", "import '../../services/"
            )
            text = text.replace(
                "import '../config/", "import '../../config/"
            )
            text = text.replace(
                "import '../providers/", "import '../../providers/"
            )
            text = text.replace(
                "import 'autoglm_service.dart'",
                "import '../../autoglm/autoglm_service.dart'",
            )
            text = text.replace(
                "import '../autoglm/autoglm_service.dart'",
                "import '../../autoglm/autoglm_service.dart'",
            )

        if domain == "settings":
            text = text.replace(
                "import 'pages/ai/", "import '../ai/"
            )
            text = text.replace(
                "import 'memory_timeline_page.dart'",
                "import '../profile/memory_timeline_page.dart'",
            )

    return text


def main() -> None:
    for path in LIB.rglob("*.dart"):
        if "pages" not in path.relative_to(LIB).parts:
            continue
        old = path.read_text(encoding="utf-8")
        new = fix_content(path, old)
        if new != old:
            path.write_text(new, encoding="utf-8")
            print("fixed", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
