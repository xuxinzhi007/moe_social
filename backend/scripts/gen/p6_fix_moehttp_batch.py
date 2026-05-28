#!/usr/bin/env python3
"""Batch-fix remaining moehttp P6 bridge issues."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# --- admin_service_compat ---
admin = (ROOT / "api/moehttp/admin_service_compat.go").read_text(encoding="utf-8")
admin = admin.replace(
    "items = append(items, rpcAdminPostReportToTypes(r))",
    "items = append(items, rpcAdminPostReportToTypes(adminv1.AdminPostReportItemToMoe(r)))",
)
admin = admin.replace(
    "common.RpcVipPlanToTypes(adminv1.VipPlanToMoe(rpcResp.GetPlan()))",
    "common.RpcVipPlanToTypes(rpcResp.GetPlan())",
)
(ROOT / "api/moehttp/admin_service_compat.go").write_text(admin, encoding="utf-8")
print("admin_service_compat ok")

# --- ai_compat ---
ai = (ROOT / "api/moehttp/ai_compat.go").read_text(encoding="utf-8")
if 'aiv1 "backend/api/ai/v1"' not in ai:
    ai = ai.replace(
        '"backend/rpc/pb/moe"',
        'aiv1 "backend/api/ai/v1"\n\tllmv1 "backend/api/llm/v1"\n\t"backend/rpc/pb/moe"',
        1,
    )

repls = [
    (
        "resp, err := app.ListPublicAiAgents(ctx, &moe.ListPublicAiAgentsReq{Limit: limit})",
        "resp, err := app.ListPublicAiAgents(ctx, aiv1.ListPublicAiAgentsReqFromMoe(&moe.ListPublicAiAgentsReq{Limit: limit}))",
    ),
    (
        "resp, err := app.GetAiUserConfig(ctx, &moe.GetAiUserConfigReq{",
        "resp, err := app.GetAiUserConfig(ctx, llmv1.GetAiUserConfigReqFromMoe(&moe.GetAiUserConfigReq{",
    ),
    (
        "resp, rpcErr := app.UpsertAiUserConfig(ctx, &moe.UpsertAiUserConfigReq{",
        "resp, rpcErr := app.UpsertAiUserConfig(ctx, llmv1.UpsertAiUserConfigReqFromMoe(&moe.UpsertAiUserConfigReq{",
    ),
    (
        "if cur, getErr := app.GetAiUserConfig(ctx, &moe.GetAiUserConfigReq{UserId: uid}); getErr == nil && cur != nil {",
        "if cur, getErr := app.GetAiUserConfig(ctx, llmv1.GetAiUserConfigReqFromMoe(&moe.GetAiUserConfigReq{UserId: uid})); getErr == nil && cur != nil {",
    ),
    (
        "if _, rpcErr := app.UpsertAiUserConfig(ctx, &moe.UpsertAiUserConfigReq{",
        "if _, rpcErr := app.UpsertAiUserConfig(ctx, llmv1.UpsertAiUserConfigReqFromMoe(&moe.UpsertAiUserConfigReq{",
    ),
    (
        "resp, err := app.GetAiUserConfig(ctx, &moe.GetAiUserConfigReq{UserId: userID})",
        "resp, err := app.GetAiUserConfig(ctx, llmv1.GetAiUserConfigReqFromMoe(&moe.GetAiUserConfigReq{UserId: userID}))",
    ),
]
for old, new in repls:
    ai = ai.replace(old, new)

# Close FromMoe calls missing )
import re

def close_from_moe(text: str) -> str:
    lines = text.splitlines()
    out = []
    for i, ln in enumerate(lines):
        if "FromMoe(&moe." in ln and "GetAiUserConfig" in ln or "FromMoe(&moe." in ln and (
            "UpsertAiUserConfig" in ln or "ListPublicAiAgents" in ln
        ):
            pass
        if ln.rstrip() == "})" and i + 1 < len(lines):
            chunk = "\n".join(lines[max(0, i - 8) : i + 1])
            if "FromMoe(&moe." in chunk and "if err" in lines[i + 1] or "if rpcErr" in lines[i + 1] or "getErr" in lines[i + 1] or "});" in lines[i + 1]:
                if not chunk.rstrip().endswith("}))"):
                    ln = ln.replace("})", "}))", 1)
        out.append(ln)
    return "\n".join(out) + "\n"


ai = close_from_moe(ai)

# aiListResource block
old_block = """func aiListResource(ctx khttp.Context, app *aiapp.AppService, userID uint, kind string) ([]map[string]interface{}, types.BaseResp) {
	req := &moe.ListAiResourceReq{UserId: strconv.FormatUint(uint64(userID), 10)}
	var (
		resp *moe.ListAiResourceResp
		err  error
	)
	switch kind {
	case "providers":
		resp, err = app.ListAiProviders(ctx, req)
	case "agents":
		resp, err = app.ListAiAgents(ctx, req)
	case "lorebooks":
		resp, err = app.ListAiLorebooks(ctx, req)"""

new_block = """func aiListResource(ctx khttp.Context, app *aiapp.AppService, userID uint, kind string) ([]map[string]interface{}, types.BaseResp) {
	req := aiv1.ListAiResourceReqFromMoe(&moe.ListAiResourceReq{UserId: strconv.FormatUint(uint64(userID), 10)})
	var (
		resp *aiv1.ListAiResourceResp
		err  error
	)
	switch kind {
	case "providers":
		resp, err = app.ListAiProviders(ctx, req)
	case "agents":
		resp, err = app.ListAiAgents(ctx, req)
	case "lorebooks":
		resp, err = app.ListAiLorebooks(ctx, req)"""

ai = ai.replace(old_block, new_block)

ai = ai.replace(
    """	req := &moe.UpsertAiResourceReq{
		UserId:      strconv.FormatUint(uint64(userID), 10),
		Id:          id,
		PayloadJson: string(raw),
	}
	var rpcErr error
	switch kind {
	case "providers":
		_, rpcErr = app.UpsertAiProvider(ctx, req)
	case "agents":
		_, rpcErr = app.UpsertAiAgent(ctx, req)
	case "lorebooks":
		_, rpcErr = app.UpsertAiLorebook(ctx, req)""",
    """	req := aiv1.UpsertAiResourceReqFromMoe(&moe.UpsertAiResourceReq{
		UserId:      strconv.FormatUint(uint64(userID), 10),
		Id:          id,
		PayloadJson: string(raw),
	})
	var rpcErr error
	switch kind {
	case "providers":
		_, rpcErr = app.UpsertAiProvider(ctx, req)
	case "agents":
		_, rpcErr = app.UpsertAiAgent(ctx, req)
	case "lorebooks":
		_, rpcErr = app.UpsertAiLorebook(ctx, req)""",
)

ai = ai.replace(
    """	req := &moe.DeleteAiResourceReq{
		UserId: strconv.FormatUint(uint64(userID), 10),
		Id:     id,
	}
	var err error
	switch kind {
	case "providers":
		_, err = app.DeleteAiProvider(ctx, req)
	case "agents":
		_, err = app.DeleteAiAgent(ctx, req)
	case "lorebooks":
		_, err = app.DeleteAiLorebook(ctx, req)""",
    """	req := aiv1.DeleteAiResourceReqFromMoe(&moe.DeleteAiResourceReq{
		UserId: strconv.FormatUint(uint64(userID), 10),
		Id:     id,
	})
	var err error
	switch kind {
	case "providers":
		_, err = app.DeleteAiProvider(ctx, req)
	case "agents":
		_, err = app.DeleteAiAgent(ctx, req)
	case "lorebooks":
		_, err = app.DeleteAiLorebook(ctx, req)""",
)

# Fix GetAiUserConfig / Upsert closing parens for multi-line blocks
for marker in (
    "GetAiUserConfigReqFromMoe(&moe.GetAiUserConfigReq{",
    "UpsertAiUserConfigReqFromMoe(&moe.UpsertAiUserConfigReq{",
):
    lines = ai.splitlines()
    out = []
    in_block = False
    for ln in lines:
        if marker in ln:
            in_block = True
        if in_block and ln.rstrip() == "})":
            ln = "\t\t}))"
            in_block = False
        out.append(ln)
    ai = "\n".join(out) + "\n"

(ROOT / "api/moehttp/ai_compat.go").write_text(ai, encoding="utf-8")
print("ai_compat ok")
