#!/usr/bin/env python3
"""Wrap service methods: moe signatures -> domain v1 with ToMoe/FromMoe bridge.

Usage:
  python scripts/gen/p6_wrap_service.py admin internal/service/admin/app.go
  python scripts/gen/p6_wrap_service.py user internal/service/user/app.go
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

PKG = {
    "admin": ("adminv1", 'adminv1 "backend/api/admin/v1"'),
    "user": ("userv1", 'userv1 "backend/api/user/v1"'),
}


def wrap_file(domain: str, path: Path) -> None:
    gopkg, import_line = PKG[domain]
    text = path.read_text(encoding="utf-8")
    if import_line.split()[0] in text:
        pass
    else:
        text = text.replace(
            '"backend/rpc/pb/moe"',
            import_line + "\n\t\"backend/rpc/pb/moe\"",
            1,
        )

    func_re = re.compile(
        r"(func \(s \*AppService\) \w+\([^)]*?)(\*moe\.(\w+))([^)]*\) \()(\*moe\.(\w+))(, error)",
        re.DOTALL,
    )

    def repl(m: re.Match) -> str:
        req, req_name, mid, resp, resp_name, tail = m.group(1), m.group(3), m.group(4), m.group(5), m.group(6), m.group(7)
        return f"{req}*{gopkg}.{req_name}{mid}(*{gopkg}.{resp_name}{tail}"

    text = func_re.sub(repl, text)

    # Wrap returns: return X, nil -> return pkg.XFromMoe(X), nil when X is &moe.T or bare moe resp
    ret_re = re.compile(
        r"return (&moe\.(\w+)\{[^}]*\}), nil",
        re.DOTALL,
    )

    def ret_repl(m: re.Match) -> str:
        name = m.group(2)
        return f"return {gopkg}.{name}FromMoe({m.group(1)}), nil"

    text = ret_re.sub(ret_repl, text)

    ret_re2 = re.compile(r"return (\w+), nil\n")
    # skip - too broad

    # Prefix: after func body open, if has `in *pkg.` convert in.Get to moeIn
    lines = text.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = re.match(r"func \(s \*AppService\) \w+\(ctx context\.Context, in \*" + gopkg + r"\.(\w+)\)", line)
        if m and i + 1 < len(lines) and lines[i + 1].strip() == "{":
            req = m.group(1)
            out.append(lines[i + 1])
            i += 2
            out.append(f"\tmoeIn := {gopkg}.{req}ToMoe(in)")
            # rewrite following lines until closing - replace in.Get with moeIn.Get
            depth = 1
            while i < len(lines) and depth > 0:
                ln = lines[i]
                if "{" in ln:
                    depth += ln.count("{") - ln.count("}")
                if "}" in ln:
                    depth -= ln.count("}")
                if depth == 0:
                    out.append(ln)
                    i += 1
                    break
                out.append(ln.replace("in.Get", "moeIn.Get").replace("in.Get", "moeIn.Get"))
                i += 1
            continue
        i += 1

    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print("wrapped", path)


if __name__ == "__main__":
    wrap_file(sys.argv[1], Path(sys.argv[2]))
