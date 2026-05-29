#!/usr/bin/env python3
"""Wrap admin/app.go passthrough returns: adminbiz -> adminv1 via ToMoe/FromMoe."""
from __future__ import annotations

import re
from pathlib import Path

APP = Path(__file__).resolve().parents[2] / "internal/service/admin/app.go"
PKG = "adminv1"


def wrap_return(line: str, resp_type: str, req_type: str | None) -> list[str]:
    m = re.match(r"\treturn adminbiz\.(\w+)\((.*)\)\s*$", line)
    if not m:
        return [line]
    func, args = m.group(1), m.group(2)
    if req_type and re.search(r"\bin\b", args):
        args = re.sub(r"\bin\b", f"{PKG}.{req_type}ToMoe(in)", args)
    indent = "\t"
    return [
        f"{indent}out, err := adminbiz.{func}({args})",
        f"{indent}if err != nil {{",
        f"{indent}\treturn nil, err",
        f"{indent}}}",
        f"{indent}return {PKG}.{resp_type}FromMoe(out), nil",
    ]


def main() -> None:
    lines = APP.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith("func (s *AppService)") and i + 1 < len(lines):
            sig = line
            m_resp = re.search(r"\(\*adminv1\.(\w+), error\)", sig)
            m_req = re.search(r"in \*adminv1\.(\w+)", sig)
            resp_type = m_resp.group(1) if m_resp else None
            req_type = m_req.group(1) if m_req else None
            out.append(line)
            i += 1
            # copy body until next func at column 0 or EOF
            while i < len(lines):
                ln = lines[i]
                if ln.startswith("func (s *AppService)"):
                    break
                if resp_type and ln.strip().startswith("return adminbiz."):
                    out.extend(wrap_return(ln, resp_type, req_type))
                    i += 1
                    continue
                out.append(ln)
                i += 1
            continue
        out.append(line)
        i += 1
    APP.write_text("\n".join(out) + "\n", encoding="utf-8")
    print("wrapped", APP)


if __name__ == "__main__":
    main()
