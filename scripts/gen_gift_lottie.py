#!/usr/bin/env python3
"""Generate tiered gift_burst_*.json Lottie templates (center-safe, tintable)."""

from __future__ import annotations

import json
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "lottie" / "gifts"


def kf_o(times_vals: list[tuple[float, float]]) -> list[dict]:
    out: list[dict] = []
    for i in range(len(times_vals) - 1):
        t0, v0 = times_vals[i]
        _, v1 = times_vals[i + 1]
        out.append(
            {
                "t": t0,
                "s": [v0],
                "e": [v1],
                "i": {"x": [0.667], "y": [1]},
                "o": {"x": [0.333], "y": [0]},
            }
        )
    out.append({"t": times_vals[-1][0]})
    return out


def kf_s(times_vals: list[tuple[float, float]]) -> list[dict]:
    out: list[dict] = []
    for i in range(len(times_vals) - 1):
        t0, v0 = times_vals[i]
        _, v1 = times_vals[i + 1]
        out.append(
            {
                "t": t0,
                "s": [v0, v0],
                "e": [v1, v1],
                "i": {"x": [0.667, 0.667], "y": [1, 1]},
                "o": {"x": [0.333, 0.333], "y": [0, 0]},
            }
        )
    out.append({"t": times_vals[-1][0]})
    return out


def ellipse_layer(
    name: str,
    ix: int,
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    color: list[float],
    opacity_k: list[dict],
    scale_k: list[dict],
    frames: int,
    pos_k: dict | None = None,
) -> dict:
    return {
        "ddd": 0,
        "ind": ix,
        "ty": 4,
        "nm": name,
        "sr": 1,
        "ks": {
            "o": {"a": 1, "k": opacity_k},
            "r": {"a": 0, "k": 0},
            "p": pos_k if pos_k is not None else {"a": 0, "k": [cx, cy]},
            "a": {"a": 0, "k": [0, 0]},
            "s": {"a": 1, "k": scale_k},
        },
        "ao": 0,
        "shapes": [
            {
                "ty": "el",
                "p": {"a": 0, "k": [0, 0]},
                "s": {"a": 0, "k": [rx * 2, ry * 2]},
                "nm": "Ellipse",
                "d": 1,
            },
            {
                "ty": "fl",
                "c": {"a": 0, "k": color + [1]},
                "o": {"a": 0, "k": 100},
                "r": 1,
                "nm": "Fill",
            },
            {
                "ty": "tr",
                "p": {"a": 0, "k": [0, 0]},
                "a": {"a": 0, "k": [0, 0]},
                "s": {"a": 0, "k": [100, 100]},
                "r": {"a": 0, "k": 0},
                "o": {"a": 0, "k": 100},
                "sk": {"a": 0, "k": 0},
                "sa": {"a": 0, "k": 0},
                "nm": "Transform",
            },
        ],
        "ip": 0,
        "op": frames,
        "st": 0,
        "bm": 0,
    }


def make(
    name: str,
    frames: int,
    particle_count: int,
    ring_count: int,
    glow_size: float,
    colors: list[list[float]],
) -> None:
    layers: list[dict] = []
    ix = 1
    layers.append(
        ellipse_layer(
            "glow",
            ix,
            200,
            200,
            glow_size,
            glow_size,
            colors[0],
            kf_o(
                [
                    (0, 0),
                    (int(frames * 0.12), 70),
                    (int(frames * 0.55), 45),
                    (int(frames * 0.9), 0),
                    (frames, 0),
                ]
            ),
            kf_s(
                [
                    (0, 20),
                    (int(frames * 0.15), 100),
                    (int(frames * 0.7), 110),
                    (frames, 40),
                ]
            ),
            frames,
        )
    )
    ix += 1

    for r in range(ring_count):
        size = 40 + r * 28
        delay = int(frames * 0.08 * r)
        layers.append(
            ellipse_layer(
                f"ring{r}",
                ix,
                200,
                200,
                size,
                size,
                colors[min(r, len(colors) - 1)],
                kf_o(
                    [
                        (delay, 0),
                        (delay + 8, 55),
                        (delay + int(frames * 0.45), 20),
                        (delay + int(frames * 0.7), 0),
                        (frames, 0),
                    ]
                ),
                kf_s(
                    [
                        (delay, 30),
                        (delay + int(frames * 0.35), 160 + r * 20),
                        (delay + int(frames * 0.7), 200 + r * 30),
                        (frames, 220),
                    ]
                ),
                frames,
            )
        )
        ix += 1

    for i in range(particle_count):
        ang = (2 * math.pi * i) / particle_count + (i % 3) * 0.2
        dist0 = 30
        dist1 = 90 + (i % 5) * 18
        x0, y0 = 200 + math.cos(ang) * dist0, 200 + math.sin(ang) * dist0
        x1, y1 = 200 + math.cos(ang) * dist1, 200 + math.sin(ang) * dist1
        delay = int(frames * 0.12) + (i % 4) * 2
        pos_k = {
            "a": 1,
            "k": [
                {
                    "t": delay,
                    "s": [x0, y0, 0],
                    "e": [x1, y1, 0],
                    "i": {"x": 0.667, "y": 1},
                    "o": {"x": 0.333, "y": 0},
                },
                {"t": delay + int(frames * 0.55)},
            ],
        }
        sz = 4 + (i % 4) * 2
        c = colors[i % len(colors)]
        layers.append(
            {
                "ddd": 0,
                "ind": ix,
                "ty": 4,
                "nm": f"p{i}",
                "sr": 1,
                "ks": {
                    "o": {
                        "a": 1,
                        "k": kf_o(
                            [
                                (delay, 0),
                                (delay + 4, 100),
                                (delay + int(frames * 0.5), 60),
                                (delay + int(frames * 0.75), 0),
                                (frames, 0),
                            ]
                        ),
                    },
                    "r": {"a": 0, "k": 0},
                    "p": pos_k,
                    "a": {"a": 0, "k": [0, 0]},
                    "s": {
                        "a": 1,
                        "k": kf_s(
                            [
                                (delay, 40),
                                (delay + 8, 120),
                                (delay + int(frames * 0.6), 60),
                                (frames, 20),
                            ]
                        ),
                    },
                },
                "ao": 0,
                "shapes": [
                    {
                        "ty": "el",
                        "p": {"a": 0, "k": [0, 0]},
                        "s": {"a": 0, "k": [sz * 2, sz * 2]},
                        "nm": "E",
                        "d": 1,
                    },
                    {
                        "ty": "fl",
                        "c": {"a": 0, "k": c + [1]},
                        "o": {"a": 0, "k": 100},
                        "r": 1,
                        "nm": "F",
                    },
                    {
                        "ty": "tr",
                        "p": {"a": 0, "k": [0, 0]},
                        "a": {"a": 0, "k": [0, 0]},
                        "s": {"a": 0, "k": [100, 100]},
                        "r": {"a": 0, "k": 0},
                        "o": {"a": 0, "k": 100},
                        "sk": {"a": 0, "k": 0},
                        "sa": {"a": 0, "k": 0},
                        "nm": "T",
                    },
                ],
                "ip": 0,
                "op": frames,
                "st": 0,
                "bm": 0,
            }
        )
        ix += 1

    doc = {
        "v": "5.7.4",
        "fr": 60,
        "ip": 0,
        "op": frames,
        "w": 400,
        "h": 400,
        "nm": name,
        "ddd": 0,
        "assets": [],
        "layers": list(reversed(layers)),
    }
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.json"
    path.write_text(json.dumps(doc, separators=(",", ":")), encoding="utf-8")
    print(f"{path} {path.stat().st_size} bytes layers={len(layers)}")


def main() -> None:
    gold = [0.95, 0.85, 0.45]
    white = [1.0, 1.0, 1.0]
    soft = [0.9, 0.92, 1.0]
    amber = [1.0, 0.75, 0.35]
    make("gift_burst_basic", 90, 10, 1, 55, [white, soft, gold])
    make("gift_burst_medium", 120, 16, 2, 70, [white, gold, soft, amber])
    make("gift_burst_advanced", 150, 24, 2, 85, [gold, white, amber, soft])
    make(
        "gift_burst_luxury",
        210,
        32,
        3,
        110,
        [gold, amber, white, soft, [1.0, 0.9, 0.5]],
    )
    print("done", OUT)


if __name__ == "__main__":
    main()
