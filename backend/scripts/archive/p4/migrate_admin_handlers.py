#!/usr/bin/env python3
"""Inline api/internal/logic/admin into api/internal/handler/admin handlers."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2]
HANDLER_DIR = BACKEND / "api" / "internal" / "handler" / "admin"
LOGIC_DIR = BACKEND / "api" / "internal" / "logic" / "admin"
SKIP = {
    "adminlistlandingfeedbackhandler.go",
    "adminstreammoebrainpipelinehandler.go",
}

IMPORT_RULES = [
    (r"\bcommon\.", '"backend/internal/apilegacy/common"'),
    (r"\bhandlerutil\.", '"backend/api/internal/handler/handlerutil"'),
    (r"\bmoebridge\.", '"backend/internal/apilegacy/moebridge"'),
    (r"\bmoe\.", '"backend/rpc/pb/moe"'),
    (r"\butils\.", '"backend/utils"'),
    (r"\bmodel\.", '"backend/model"'),
    (r"\bruntime\.", '"backend/pkg/moe/runtime"'),
    (r"\bbrain\.", '"backend/pkg/moe/brain"'),
    (r"\bllminference\.", '"backend/pkg/llminference"'),
    (r"\bstrings\.", '"strings"'),
    (r"\bstrconv\.", '"strconv"'),
    (r"\bfmt\.", '"fmt"'),
    (r"\bcontext\.", '"context"'),
    (r"\btime\.", '"time"'),
    (r"\bjson\.", '"encoding/json"'),
    (r"\bio\.", '"io"'),
    (r"\bhttp\.", '"net/http"'),
]


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def write(p: Path, s: str) -> None:
    p.write_text(s, encoding="utf-8", newline="\n")


def extract_func_body(src: str, type_name: str, method_name: str) -> str | None:
    pat = rf"func \(l \*{re.escape(type_name)}\) {re.escape(method_name)}\([^)]*\)[^{{]*\{{"
    m = re.search(pat, src)
    if not m:
        return None
    i, depth = m.end(), 1
    while i < len(src) and depth:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
        i += 1
    return src[m.end() : i - 1].strip()


def extract_file_helpers(src: str, type_name: str) -> str:
    """Non-method funcs in logic file (e.g. modelInList)."""
    parts = []
    for m in re.finditer(r"^func (\w+)\(", src, re.M):
        name = m.group(1)
        if name.startswith("New") or name == "main":
            continue
        body = extract_func_body_by_name(src, name)
        if body:
            parts.append(f"func {name}{body}")
    return "\n\n".join(parts)


def extract_func_body_by_name(src: str, func_name: str) -> str | None:
    pat = rf"^func {re.escape(func_name)}\([^)]*\)[^{{]*\{{"
    m = re.search(pat, src, re.M)
    if not m:
        return None
    i, depth = m.end(), 1
    while i < len(src) and depth:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
        i += 1
    sig_m = re.search(rf"^func {re.escape(func_name)}\([^)]*\)", src, re.M)
    sig = sig_m.group(0)[4:] if sig_m else f"{func_name}()"
    return sig + " {" + src[m.end() : i - 1] + "}"


def find_logic(ctor: str) -> tuple[Path, str, str, str] | None:
    if not ctor.startswith("New") or not ctor.endswith("Logic"):
        return None
    type_name = ctor[3:]
    method_name = type_name[: -5]
    for p in sorted(LOGIC_DIR.glob("*.go")):
        src = read(p)
        if f"type {type_name} struct" not in src:
            continue
        body = extract_func_body(src, type_name, method_name)
        if body:
            helpers = extract_file_helpers(src, type_name)
            return p, type_name, method_name, body, helpers
    return None


def sort_imports(imps: set[str]) -> list[str]:
    std, ext, local = [], [], []
    for imp in imps:
        if imp.startswith('"backend/'):
            local.append(imp)
        elif imp.startswith('"github.com') or imp.startswith('"go.'):
            ext.append(imp)
        else:
            std.append(imp)
    return sorted(std) + sorted(ext) + sorted(local)


def collect_imports(*chunks: str) -> list[str]:
    imps = {
        '"net/http"',
        '"backend/internal/apilegacy/svc"',
        '"backend/internal/legacy/types"',
        '"github.com/zeromicro/go-zero/rest/httpx"',
    }
    text = "\n".join(chunks)
    for rx, imp in IMPORT_RULES:
        if re.search(rx, text):
            imps.add(imp)
    return sort_imports(imps)


def transform_body(body: str, ctx_expr: str) -> list[str]:
    body = body.replace("l.svcCtx", "svcCtx").replace("l.ctx", ctx_expr)
    body = body.replace("parseAdminPathID(", "handlerutil.ParseAdminPathID(")
    lines = []
    for raw in body.split("\n"):
        s = raw.strip()
        if s.startswith("return ") and s.endswith(", nil"):
            expr = s[7:-5].strip()
            lines.append(f"resp, err = {expr}, nil")
        elif s.startswith("return "):
            lines.append(s)
        else:
            lines.append(raw.strip() or "")
    return lines


def auth_block(handler_src: str, resp_type: str) -> tuple[list[str], str, bool]:
    if "PrepareAdminContext" in handler_src:
        return (
            [
                "\t\tctx, ok := common.PrepareAdminContext(w, r)",
                "\t\tif !ok {",
                "\t\t\treturn",
                "\t\t}",
            ],
            "ctx",
            True,
        )
    if "claims, br := common.RequireAdminToken" in handler_src:
        return (
            [
                "\t\tclaims, br := common.RequireAdminToken(r)",
                f"\t\tif br != nil {{",
                f"\t\t\thttpx.OkJsonCtx(r.Context(), w, &types.{resp_type}{{BaseResp: *br}})",
                "\t\t\treturn",
                "\t\t}",
            ],
            "r.Context()",
            False,
        )
    if "RequireAdminToken" in handler_src:
        return (
            [
                "\t\tif _, br := common.RequireAdminToken(r); br != nil {",
                f"\t\t\thttpx.OkJsonCtx(r.Context(), w, &types.{resp_type}{{BaseResp: *br}})",
                "\t\t\treturn",
                "\t\t}",
            ],
            "r.Context()",
            False,
        )
    return [], "r.Context()", False


def migrate(handler_path: Path) -> str:
    name = handler_path.name
    if name in SKIP:
        return "skip"
    hsrc = read(handler_path)
    if "logic/admin" not in hsrc:
        return "no-logic"

    ctor_m = re.search(r"admin\.(New\w+Logic)\(", hsrc)
    func_m = re.search(r"func (Admin\w+Handler)\(", hsrc)
    req_m = re.search(r"var req types\.(\w+)", hsrc)
    call_m = re.search(r"l\.(\w+)\(([^)]*)\)", hsrc)
    if not ctor_m or not func_m:
        return "parse-handler-fail"

    found = find_logic(ctor_m.group(1))
    if not found:
        return f"no-logic:{ctor_m.group(1)}"

    _, type_name, method_name, body, helpers = found
    func_name = func_m.group(1)
    req_type = req_m.group(1) if req_m else None
    resp_type = (req_type.replace("Req", "Resp", 1) if req_type else method_name + "Resp")
    call_arg = call_m.group(2).strip() if call_m else "&req"

    auth, ctx_expr, _ = auth_block(hsrc, resp_type)

    if func_name == "AdminRuntimeOverviewHandler":
        content = "\n".join(
            [
                "package admin",
                "",
                "import (",
                '\t"net/http"',
                "",
                '\t"backend/api/internal/handler/handlerutil"',
                '\t"backend/internal/apilegacy/svc"',
                '\t"backend/internal/legacy/types"',
                '\t"github.com/zeromicro/go-zero/rest/httpx"',
                ")",
                "",
                f"func {func_name}(svcCtx *svc.ServiceContext) http.HandlerFunc {{",
                "\treturn func(w http.ResponseWriter, r *http.Request) {",
                f"\t\tvar req types.EmptyReq",
                "\t\tif err := httpx.Parse(r, &req); err != nil {",
                "\t\t\thttpx.ErrorCtx(r.Context(), w, err)",
                "\t\t\treturn",
                "\t\t}",
                f"\t\tresp := handlerutil.AdminRuntimeOverview(r.Context(), svcCtx)",
                "\t\thttpx.OkJsonCtx(r.Context(), w, resp)",
                "\t}",
                "}",
                "",
            ]
        )
        write(handler_path, content)
        return "ok"

    imps = collect_imports(body, helpers, hsrc)
    lines = ["package admin", "", "import (", "\t" + ",\n\t".join(imps) + ",", ")", ""]
    lines.append(f"func {func_name}(svcCtx *svc.ServiceContext) http.HandlerFunc {{")
    lines.append("\treturn func(w http.ResponseWriter, r *http.Request) {")
    lines.extend(auth)

    if req_type:
        lines += [
            f"\t\tvar req types.{req_type}",
            "\t\tif err := httpx.Parse(r, &req); err != nil {",
            f"\t\t\thttpx.ErrorCtx({ctx_expr}, w, err)",
            "\t\t\treturn",
            "\t\t}",
        ]

    if call_arg == "claims":
        inner = transform_body(body.replace("claims", "claims"), ctx_expr)
        lines.append(f"\t\tresp, err := func(claims *utils.AdminClaims) (*types.{resp_type}, error) {{")
        lines.append(f"\t\t\tvar resp *types.{resp_type}")
        lines.append("\t\t\tvar err error")
        for ln in inner:
            lines.append("\t\t\t" + ln if ln else "")
        lines.append("\t\t\treturn resp, err")
        lines.append("\t\t}(claims)")
    else:
        inner = transform_body(body, ctx_expr)
        lines.append(f"\t\tvar resp *types.{resp_type}")
        lines.append("\t\tvar err error")
        for ln in inner:
            lines.append("\t\t" + ln if ln else "")

    if helpers:
        for hl in helpers.split("\n\n"):
            for hln in hl.split("\n"):
                lines.append("\t\t" + hln)

    lines += [
        "\t\tif err != nil {",
        f"\t\t\thttpx.ErrorCtx({ctx_expr}, w, err)",
        "\t\t} else {",
        f"\t\t\thttpx.OkJsonCtx({ctx_expr}, w, resp)",
        "\t\t}",
        "\t}",
        "}",
        "",
    ]
    write(handler_path, "\n".join(lines))
    return "ok"


def main() -> int:
    os.chdir(BACKEND)
    failed = {}
    ok = 0
    for hp in sorted(HANDLER_DIR.glob("*handler.go")):
        st = migrate(hp)
        if st == "ok":
            ok += 1
        elif st not in ("skip", "no-logic"):
            failed[hp.name] = st
    print(f"ok={ok} failed={len(failed)}")
    for k, v in sorted(failed.items()):
        print(f"  {k}: {v}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
