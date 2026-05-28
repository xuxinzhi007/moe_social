package llm

import (
	"context"

	llmbiz "backend/internal/biz/llm"
	"backend/api/internal/svc"
	"backend/rpc/pb/moe"
)

// UserMemoryAutoLearnEnabled 读取用户是否开启回合后自动提取记忆（默认 true）。
func UserMemoryAutoLearnEnabled(ctx context.Context, svcCtx *svc.ServiceContext, userID string) bool {
	if svcCtx == nil || svcCtx.LLMGW == nil || userID == "" {
		return true
	}
	resp, err := svcCtx.LLMGW.GetAiUserConfig(ctx, &moe.GetAiUserConfigReq{UserId: userID})
	if err != nil || resp == nil {
		return true
	}
	return llmbiz.MemoryAutoLearnEnabled(llmbiz.DecodePreferencesJSON(resp.GetPreferencesJson()))
}

// DecodePreferencesJSON 解析 ai_user_config.preferences_json。
func DecodePreferencesJSON(raw string) map[string]interface{} {
	return llmbiz.DecodePreferencesJSON(raw)
}

// MergeMemoryAutoLearnPref 合并 memory_auto_learn 开关。
func MergeMemoryAutoLearnPref(existing map[string]interface{}, autoLearn bool) string {
	return llmbiz.MergeMemoryAutoLearnPref(existing, autoLearn)
}
