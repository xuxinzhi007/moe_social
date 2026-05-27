package llm

import (
	"context"
	"encoding/json"
	"strconv"

	"backend/api/internal/svc"
	"backend/rpc/pb/super"
)

// UserMemoryAutoLearnEnabled 读取用户是否开启回合后自动提取记忆（默认 true）。
func UserMemoryAutoLearnEnabled(ctx context.Context, svcCtx *svc.ServiceContext, userID string) bool {
	if svcCtx == nil || svcCtx.LLMGW == nil || userID == "" {
		return true
	}
	resp, err := svcCtx.LLMGW.GetAiUserConfig(ctx, &super.GetAiUserConfigReq{UserId: userID})
	if err != nil || resp == nil {
		return true
	}
	prefs := decodePrefs(resp.GetPreferencesJson())
	if v, ok := prefs["memory_auto_learn"]; ok {
		switch t := v.(type) {
		case bool:
			return t
		case string:
			return t != "false" && t != "0"
		case float64:
			return t != 0
		}
	}
	return true
}

// DecodePreferencesJSON 解析 ai_user_config.preferences_json。
func DecodePreferencesJSON(raw string) map[string]interface{} {
	return decodePrefs(raw)
}

// MergeMemoryAutoLearnPref 合并 memory_auto_learn 开关。
func MergeMemoryAutoLearnPref(existing map[string]interface{}, autoLearn bool) string {
	return mergeMemoryAutoLearnPref(existing, autoLearn)
}

func decodePrefs(raw string) map[string]interface{} {
	if raw == "" {
		return map[string]interface{}{}
	}
	var out map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return map[string]interface{}{}
	}
	return out
}

func mergeMemoryAutoLearnPref(existing map[string]interface{}, autoLearn bool) string {
	if existing == nil {
		existing = map[string]interface{}{}
	}
	existing["memory_auto_learn"] = autoLearn
	raw, err := json.Marshal(existing)
	if err != nil {
		return `{"memory_auto_learn":` + strconv.FormatBool(autoLearn) + `}`
	}
	return string(raw)
}
