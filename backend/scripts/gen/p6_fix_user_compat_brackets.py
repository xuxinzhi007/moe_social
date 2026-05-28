#!/usr/bin/env python3
"""Fix FromMoe parentheses in user_compat.go."""
from pathlib import Path
import re


def brace_delta(s: str) -> int:
    return s.count("{") - s.count("}")


def close_frommoe_paren(lines: list[str], start: int) -> None:
    line = lines[start]
    if "FromMoe(&moe." not in line:
        return
    d = brace_delta(line)
    if d == 0:
        s = line.rstrip()
        if s.endswith("})") and not s.endswith("}))"):
            lines[start] = s + ")"
        return
    i = start + 1
    while i < len(lines) and d > 0:
        d += brace_delta(lines[i])
        i += 1
    close_i = i - 1
    if close_i > start and re.match(r"^\s+\}\)\s*$", lines[close_i]):
        lines[close_i] = re.sub(r"\}\)\s*$", "}))", lines[close_i])


def main() -> None:
    p = Path(__file__).resolve().parents[2] / "api" / "moehttp" / "user_compat.go"
    lines = p.read_text(encoding="utf-8").splitlines()

    # Reset mistaken ctx.JSON closings.
    lines = [re.sub(r"\}\)\)\s*$", "})", ln) for ln in lines]

    for i, ln in enumerate(lines):
        if re.search(r"app\.\w+\(ctx, (?:userv1|vipv1)\.\w+FromMoe", ln):
            close_frommoe_paren(lines, i)

    p.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("fixed brackets", p)


if __name__ == "__main__":
    main()
