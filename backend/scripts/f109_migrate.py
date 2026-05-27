#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F109: thin RPC handlers + replace SuperRpcClient in api/internal/logic/user."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RPC_DIR = ROOT / "rpc" / "internal" / "logic"
API_USER = ROOT / "api" / "internal" / "logic" / "user"

USER_RPC = [
    "getuserslogic.go",
    "getusercountlogic.go",
    "getuserbyemaillogic.go",
    "updateuserinfologic.go",
    "updateuserpasswordlogic.go",
    "resetpasswordlogic.go",
    "deleteuserlogic.go",
    "createviporderlogic.go",
    "updateuserviplogic.go",
    "syncuservipstatuslogic.go",
    "updateautorenewlogic.go",
    "getviprecordslogic.go",
    "getuseractiveviprecordlogic.go",
    "gettransactionslogic.go",
    "gettransactionlogic.go",
    "rechargelogic.go",
    "feishuloginlogic.go",
    "feishuauthorizeurllogic.go",
    "bindfeishulogic.go",
    "unbindfeishulogic.go",
    "sendfeishutestcardlogic.go",
    "wechatloginlogic.go",
    "wechatauthorizeurllogic.go",
    "listuserdeviceslogic.go",
    "syncuserdevicelogic.go",
]

LLM_RPC = [
    "getusermemorieslogic.go",
    "getusermemoryprofileslogic.go",
    "deleteusermemorylogic.go",
    "submitusermemoryfeedbacklogic.go",
    "rebuildusermemoryembeddingslogic.go",
    "listusermemoryembeddingslogic.go",
    "listusermemoryrelationslogic.go",
]

MEMORY_API_METHODS = {
    "GetUserMemories",
    "GetUserMemoryProfiles",
    "DeleteUserMemory",
    "SubmitUserMemoryFeedback",
    "RebuildUserMemoryEmbeddings",
    "ListUserMemoryEmbeddings",
    "ListUserMemoryRelations",
}


def rpc_method_name(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    m = re.search(r"func \(l \*\w+Logic\) (\w+)\(", text)
    if not m:
        raise ValueError(f"no method in {path}")
    return m.group(1)


def thin_rpc(path: Path, app_pkg: str) -> None:
    method = rpc_method_name(path)
    struct = method + "Logic"
    if app_pkg == "userapp":
        call = f"resp, err := userapp.New(l.svcCtx.DB).{method}(l.ctx, in)\n\treturn resp, mapUserBizErr(err)"
        extra_import = '\tuserapp "backend/internal/service/user"\n'
    else:
        call = f"resp, err := llmapp.New(l.svcCtx.DB, llmapp.Deps{{Inference: l.svcCtx.Config.LLMInference}}).{method}(l.ctx, in)\n\treturn resp, mapMemoryWriteErr(err)"
        extra_import = '\tllmapp "backend/internal/service/llm"\n'

    content = f'''package logic

import (
\t"context"

{extra_import}\t"backend/rpc/internal/svc"
\t"backend/rpc/pb/super"

\t"github.com/zeromicro/go-zero/core/logx"
)

type {struct} struct {{
\tctx    context.Context
\tsvcCtx *svc.ServiceContext
\tlogx.Logger
}}

func New{struct}(ctx context.Context, svcCtx *svc.ServiceContext) *{struct} {{
\treturn &{struct}{{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}}
}}

func (l *{struct}) {method}(in *super.{method}Req) (*super.{method}Resp, error) {{
\t{call}
}}
'''
    path.write_text(content, encoding="utf-8")
    print("thinned rpc", path.name)


def patch_api_user_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if "SuperRpcClient" not in text:
        return
    orig = text
    for m in MEMORY_API_METHODS:
        text = text.replace(f"l.svcCtx.SuperRpcClient.{m}", f"l.svcCtx.LLMGW.{m}")
    text = re.sub(r"l\.svcCtx\.SuperRpcClient\.(\w+)", r"l.svcCtx.UserGW.\1", text)
    if text != orig:
        path.write_text(text, encoding="utf-8")
        print("patched api", path.name)


def main() -> None:
    for name in USER_RPC:
        thin_rpc(RPC_DIR / name, "userapp")
    for name in LLM_RPC:
        thin_rpc(RPC_DIR / name, "llmapp")
    for go in API_USER.glob("*.go"):
        patch_api_user_file(go)
    print("done")


if __name__ == "__main__":
    main()
