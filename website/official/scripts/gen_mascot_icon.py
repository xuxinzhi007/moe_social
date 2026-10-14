#!/usr/bin/env python3
"""Generate Xiaoxing mascot brand assets (app icon master + splash images).

输入: AI 生成的白底 mascot 原图（默认 vibe_images/ 下最新 xiaoxing_mascot_raw_*.png）。
处理: 边缘泛洪去白底 -> 裁切 -> 输出透明 mascot、全幅渐变 app icon、Android/iOS 启动图。

Requires: pip install pillow

Examples:
  python website/official/scripts/gen_mascot_icon.py
  python website/official/scripts/gen_mascot_icon.py --raw path/to/raw.png
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
ASSETS_BRAND = ROOT / "assets" / "branding"
ANDROID_DRAWABLE = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable-nodpi"
IOS_LAUNCH = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"

# 与 MoeTokens.primary / gen_wechat_icons.py 品牌渐变一致。
VIOLET = (127, 127, 213)
MINT = (145, 234, 228)

ICON_MASTER = 1024
MASCOT_ON_ICON_RATIO = 0.72  # mascot 占图标宽度比例
ANDROID_SPLASH_PX = 512
IOS_LAUNCH_BASE_PX = 168  # storyboard 中 LaunchImage 的 @1x 边长


def _lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def find_raw(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit)
    candidates = sorted((ROOT / "vibe_images").glob("xiaoxing_mascot_raw_*.png"))
    if not candidates:
        sys.exit("未找到 vibe_images/xiaoxing_mascot_raw_*.png，请用 --raw 指定原图")
    return candidates[-1]


def remove_white_background(raw: Path) -> Image.Image:
    """边缘泛洪去白底：只移除与边框连通的近白区域，保留星星内部高光。"""
    img = Image.open(raw).convert("RGBA")
    flood = img.copy()
    marker = (1, 2, 3, 255)
    w, h = flood.size
    for seed in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(flood, seed, marker, thresh=60)

    src = img.load()
    mark = flood.load()
    for y in range(h):
        for x in range(w):
            if mark[x, y] == marker:
                src[x, y] = (0, 0, 0, 0)
    return img


def trim_to_content(img: Image.Image, pad_ratio: float = 0.02) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        sys.exit("去背结果为空，请检查原图背景是否为纯白")
    pad = int(max(img.size) * pad_ratio)
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(img.width, bbox[2] + pad)
    bottom = min(img.height, bbox[3] + pad)
    return img.crop((left, top, right, bottom))


def make_square(mascot: Image.Image, size: int) -> Image.Image:
    """透明底正方形画布，mascot 居中缩放到边长内。"""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    scale = min(size / mascot.width, size / mascot.height)
    w, h = int(mascot.width * scale), int(mascot.height * scale)
    resized = mascot.resize((w, h), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((size - w) // 2, (size - h) // 2), resized)
    return canvas


def make_icon_master(mascot: Image.Image, size: int = ICON_MASTER) -> Image.Image:
    """全幅紫青渐变底 + 居中 mascot（无透明边距，iOS/Android 各自套遮罩）。"""
    base = Image.new("RGBA", (size, size))
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
    target = int(size * MASCOT_ON_ICON_RATIO)
    square = make_square(mascot, target)
    base.paste(square, ((size - target) // 2, (size - target) // 2), square)
    return base


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)
    print(f"  {path.relative_to(ROOT)}  ({img.width}x{img.height}, {path.stat().st_size} B)")


def main() -> None:
    parser = argparse.ArgumentParser(description="生成小星 mascot 品牌资源")
    parser.add_argument("--raw", help="白底 mascot 原图路径，默认取 vibe_images 最新")
    args = parser.parse_args()

    raw = find_raw(args.raw)
    print(f"原图: {raw.relative_to(ROOT)}")
    mascot = trim_to_content(remove_white_background(raw))

    print("透明 mascot（Flutter splash / 通用）:")
    save(make_square(mascot, ICON_MASTER), ASSETS_BRAND / "xiaoxing_mascot.png")

    print("App 图标主图:")
    master = make_icon_master(mascot)
    save(master, OUT_BRAND / f"app_icon_mascot_{ICON_MASTER}.png")
    shutil.copy2(OUT_BRAND / f"app_icon_mascot_{ICON_MASTER}.png", ASSETS_BRAND / "app_icon.png")
    print(f"  已复制到 {ASSETS_BRAND.relative_to(ROOT)}/app_icon.png")

    print("Android 原生启动图:")
    save(make_square(mascot, ANDROID_SPLASH_PX), ANDROID_DRAWABLE / "xiaoxing_mascot.png")

    print("iOS LaunchImage:")
    for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
        px = IOS_LAUNCH_BASE_PX * scale
        save(make_square(mascot, px), IOS_LAUNCH / f"LaunchImage{suffix}.png")

    print("\n完成。下一步执行:")
    print("  dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
