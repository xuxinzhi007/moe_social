package handlerutil

import (
	"context"
	"strconv"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	llmbiz "backend/internal/biz/llm"
	"backend/rpc/pb/moe"
)

// AIUserMemoryAutoLearnEnabled 读取用户是否开启回合后自动提取记忆（默认 true）。
func AIUserMemoryAutoLearnEnabled(ctx context.Context, svcCtx *svc.ServiceContext, userID string) bool {
	if svcCtx == nil || svcCtx.LLMGW == nil || userID == "" {
		return true
	}
	resp, err := svcCtx.LLMGW.GetAiUserConfig(ctx, &moe.GetAiUserConfigReq{UserId: userID})
	if err != nil || resp == nil {
		return true
	}
	return llmbiz.MemoryAutoLearnEnabled(llmbiz.DecodePreferencesJSON(resp.GetPreferencesJson()))
}

// AIGetMemorySettings returns memory auto-learn preference.
func AIGetMemorySettings(ctx context.Context, svcCtx *svc.ServiceContext, userID uint) (*types.AiMemorySettingsResp, error) {
	uid := strconv.FormatUint(uint64(userID), 10)
	auto := AIUserMemoryAutoLearnEnabled(ctx, svcCtx, uid)
	return &types.AiMemorySettingsResp{
		BaseResp: common.HandleError(nil),
		Data:     types.AiMemorySettingsData{AutoLearn: auto},
	}, nil
}

// AIPutMemorySettings updates memory auto-learn preference.
func AIPutMemorySettings(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, req *types.AiMemorySettingsReq) (*types.AiMemorySettingsResp, error) {
	uid := strconv.FormatUint(uint64(userID), 10)
	existing := map[string]interface{}{}
	if svcCtx.LLMGW != nil {
		if cur, err := svcCtx.LLMGW.GetAiUserConfig(ctx, &moe.GetAiUserConfigReq{UserId: uid}); err == nil && cur != nil {
			existing = llmbiz.DecodePreferencesJSON(cur.GetPreferencesJson())
		}
	}
	prefsJSON := llmbiz.MergeMemoryAutoLearnPref(existing, req.AutoLearn)
	if svcCtx.LLMGW == nil {
		return &types.AiMemorySettingsResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AiMemorySettingsData{AutoLearn: req.AutoLearn},
		}, nil
	}
	_, rpcErr := svcCtx.LLMGW.UpsertAiUserConfig(ctx, &moe.UpsertAiUserConfigReq{
		UserId:          uid,
		PreferencesJson: prefsJSON,
	})
	if rpcErr != nil {
		return &types.AiMemorySettingsResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	return &types.AiMemorySettingsResp{
		BaseResp: common.HandleError(nil),
		Data:     types.AiMemorySettingsData{AutoLearn: req.AutoLearn},
	}, nil
}
