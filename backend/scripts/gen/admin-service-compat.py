#!/usr/bin/env python3
"""Generate admin_service_compat.go (Admin CRUD via adminlogic; target: inline AdminApp).

Legacy split source was admin_logic_compat.go (removed); outputs:
  - admin_legacy_compat.go  (Moe brain / runtime / media — wrapNativeHTTP)
  - admin_service_compat.go (CRUD — invokeLogicJSON → adminlogic → AdminGW)
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Historical: generated from admin_logic_compat.go (deleted). Re-run only if restoring from archive.
COMPAT = ROOT / "api/moehttp/admin_logic_compat.go"
LEGACY = ROOT / "api/moehttp/admin_legacy_compat.go"
OUT = ROOT / "api/moehttp/admin_service_compat.go"

LEGACY_PATH_PREFIXES = (
    "/api/admin/moe/",
    "/api/admin/me",
    "/api/admin/media/images",
    "/api/admin/runtime/overview",
    "/api/admin/runtime-config",
)


def is_legacy(path: str, method: str, handler: str) -> bool:
    if any(path.startswith(p) for p in LEGACY_PATH_PREFIXES):
        return True
    if path == "/api/admin/ai/agents" and method == "PUT":
        return True
    if handler in (
        "AdminMeHandler",
        "AdminListMediaImagesHandler",
        "AdminDeleteMediaImageHandler",
        "AdminRuntimeOverviewHandler",
        "AdminGetRuntimeConfigHandler",
        "AdminUpdateRuntimeConfigHandler",
        "AdminUpdateAiAgentHandler",
    ):
        return True
    return False


def handler_to_logic(handler: str) -> tuple[str, str]:
    # AdminListPostsHandler -> AdminListPosts, NewAdminListPostsLogic
    base = handler.replace("Handler", "")
    return base, f"New{base}Logic"


def main() -> None:
    text = COMPAT.read_text()
    routes = re.findall(
        r'r\.(GET|POST|PUT|DELETE)\("([^"]+)",\s*wrapNativeHTTP\(hadmin\.(\w+)\(svc\)\)\)',
        text,
    )
    legacy_lines: list[str] = []
    service_blocks: list[str] = []

    for method, path, handler in routes:
        if is_legacy(path, method, handler):
            legacy_lines.append(
                f'\tr.{method}("{path}", wrapNativeHTTP(hadmin.{handler}(svc)))'
            )
            continue
        logic_method, ctor = handler_to_logic(handler)
        fn_name = logic_method[0].lower() + logic_method[1:]
        service_blocks.append(
            f"""func {fn_name}(svcCtx *svc.ServiceContext) func(khttp.Context) error {{
\treturn func(ctx khttp.Context) error {{
\t\tvar req types.{logic_method}Req
\t\tif err := httpx.Parse(ctx.Request(), &req); err != nil {{
\t\t\treturn ctx.JSON(http.StatusBadRequest, types.BaseResp{{
\t\t\t\tCode: -1, Message: err.Error(), Success: false,
\t\t\t}})
\t\t}}
\t\tl := adminlogic.{ctor}(ctx, svcCtx)
\t\tresp, err := l.{logic_method}(&req)
\t\tif err != nil {{
\t\t\treturn err
\t\t}}
\t\treturn ctx.JSON(http.StatusOK, resp)
\t}}
}}

// register: r.{method}("{path}", {fn_name}(svcCtx))"""
        )

    reg_lines = []
    for method, path, handler in routes:
        if is_legacy(path, method, handler):
            continue
        logic_method, _ = handler_to_logic(handler)
        fn_name = logic_method[0].lower() + logic_method[1:]
        reg_lines.append(f'\tr.{method}("{path}", {fn_name}(svcCtx))')

    LEGACY.write_text(
        f"""package moehttp

import (
\t"backend/api/internal/svc"
\thadmin "backend/api/internal/handler/admin"

\tkhttp "github.com/go-kratos/kratos/v2/transport/http"
)

const PilotNativeAdminLegacyCompatRoutes = {len(legacy_lines)}

func RegisterAdminLegacyCompat(srv *khttp.Server, svc *svc.ServiceContext) {{
\tif srv == nil || svc == nil {{
\t\treturn
\t}}
\tr := srv.Route("/")
{chr(10).join(legacy_lines)}
}}
"""
    )

    OUT.write_text(
        f"""package moehttp

import (
\t"net/http"

\tadminlogic "backend/api/internal/logic/admin"
\t"backend/api/internal/svc"
\t"backend/api/internal/types"

\tkhttp "github.com/go-kratos/kratos/v2/transport/http"
\t"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativeAdminServiceCompatRoutes Admin CRUD（logic 适配；AdminGW in_process → internal/service/admin）。
const PilotNativeAdminServiceCompatRoutes = {len(reg_lines)}

func RegisterAdminServiceCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {{
\tif srv == nil || svcCtx == nil || svcCtx.AdminApp == nil {{
\t\treturn
\t}}
\tr := srv.Route("/")
{chr(10).join(reg_lines)}
}}

{chr(10).join(service_blocks)}
"""
    )
    print(f"legacy={len(legacy_lines)} service={len(reg_lines)}")


if __name__ == "__main__":
    main()
