#!/usr/bin/env python3
"""Generate Moe Social brand icons (WeChat + Flutter launcher source + Android mipmaps).

Requires: pip install pillow

Examples:
  python website/official/scripts/gen_wechat_icons.py
  python website/official/scripts/gen_wechat_icons.py --android
  python website/official/scripts/gen_wechat_icons.py --wechat-only
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("请先安装 Pillow: python -m pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[3]
OFFICIAL = Path(__file__).resolve().parent.parent
OUT_BRAND = OFFICIAL / "app-icons"
OUT_WECHAT = OFFICIAL / "wechat-icons"
ASSETS_ICON = ROOT / "assets" / "branding" / "app_icon.png"

# 与 lib/ 登录页、官网一致
VIOLET = (127, 127, 213)
MINT = (145, 234, 228)

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

WECHAT_SIZES = (28, 108)
LAUNCHER_MASTER = 1024


def _lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def make_icon(size: int) -> Image.Image:
    """紫青渐变圆角方块 + 白色 M（与官网品牌一致）。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    margin = max(1, size // 12)
    radius = max(2, size // 5)
    box = (margin, margin, size - margin - 1, size - margin - 1)

    # 对角渐变底图
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = base.load()
    denom = max(1, 2 * (size - 1))
    for y in range(size):
        for x in range(size):
            t = (x + y) / denom
            pixels[x, y] = (
                _lerp(VIOLET[0], MINT[0], t),
                _lerp(VIOLET[1], MINT[1], t),
                _lerp(VIOLET[2], MINT[2], t),
                255,
            )

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    base.putalpha(mask)
    img = base

    draw = ImageDraw.Draw(img)
    stroke = max(2, size // 12)
    left = box[0] + (box[2] - box[0]) * 0.26
    right = box[0] + (box[2] - box[0]) * 0.74
    top = box[1] + (box[3] - box[1]) * 0.20
    bottom = box[1] + (box[3] - box[1]) * 0.78
    cx = (box[0] + box[2]) / 2
    mid = box[1] + (box[3] - box[1]) * 0.46

    lines = [
        (left, bottom, left, top),
        (left, top, cx, mid),
        (cx, mid, right, top),
        (right, top, right, bottom),
    ]
    for x1, y1, x2, y2 in lines:
        draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 255), width=stroke)

    return img


def write_size(icon_fn, size: int, path: Path) -> None:
    icon = icon_fn(size)
    if icon.size != (size, size):
        raise ValueError(f"expected {size}x{size}, got {icon.size}")
    icon.save(path, format="PNG", optimize=True)
    print(f"  {path.relative_to(ROOT)}  ({size}x{size}, {path.stat().st_size} B)")


def generate_wechat(out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    print("WeChat 开放平台:")
    for s in WECHAT_SIZES:
        write_size(make_icon, s, out / f"moe-social-wechat-{s}x{s}.png")


def generate_brand_assets(out: Path) -> Path:
    out.mkdir(parents=True, exist_ok=True)
    print("品牌图标（Flutter / 各平台源图）:")
    master_path = out / f"app_icon_{LAUNCHER_MASTER}.png"
    write_size(make_icon, LAUNCHER_MASTER, master_path)
    for s in (512, 256, 192, 128, 96, 64, 48):
        write_size(make_icon, s, out / f"app_icon_{s}.png")
    return master_path


def copy_android(master: Image.Image) -> None:
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    print("写入 Android 启动图标:")
    for folder, size in ANDROID_SIZES.items():
        dest = res / folder / "ic_launcher.png"
        dest.parent.mkdir(parents=True, exist_ok=True)
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(dest, format="PNG", optimize=True)
        print(f"  {dest.relative_to(ROOT)}  ({size}x{size})")


def install_flutter_asset(master_path: Path) -> None:
    ASSETS_ICON.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(master_path, ASSETS_ICON)
    print(f"已复制到 Flutter 资源: {ASSETS_ICON.relative_to(ROOT)}")
    print("下一步请执行: dart run flutter_launcher_icons")


def main() -> None:
    parser = argparse.ArgumentParser(description="生成 Moe Social 品牌图标")
    parser.add_argument(
        "--wechat-only",
        action="store_true",
        help="仅生成微信 28/108 图标",
    )
    parser.add_argument(
        "--android",
        action="store_true",
        help="将图标写入 android/app/src/main/res/mipmap-*",
    )
    parser.add_argument(
        "--flutter-asset",
        action="store_true",
        help="复制 1024 主图到 assets/branding/app_icon.png",
    )
    args = parser.parse_args()

    if args.wechat_only:
        generate_wechat(OUT_WECHAT)
        return

    master_path = generate_brand_assets(OUT_BRAND)
    generate_wechat(OUT_WECHAT)

    master = Image.open(master_path)

    do_all = not args.wechat_only and not args.android and not args.flutter_asset
    if args.android or do_all:
        copy_android(master)
    if args.flutter_asset or do_all:
        install_flutter_asset(master_path)

    print("\n完成。打包 App 前建议执行:")
    print("  dart run flutter_launcher_icons")
    print("  flutter clean && flutter run")


if __name__ == "__main__":
    main()
