package llmbiz

import (
	"encoding/json"
	"strconv"
)

// DecodePreferencesJSON 解析 ai_user_config.preferences_json。
func DecodePreferencesJSON(raw string) map[string]interface{} {
	if raw == "" {
		return map[string]interface{}{}
	}
	var out map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return map[string]interface{}{}
	}
	return out
}

// MergeMemoryAutoLearnPref 合并 memory_auto_learn 开关。
func MergeMemoryAutoLearnPref(existing map[string]interface{}, autoLearn bool) string {
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

// MemoryAutoLearnEnabled 读取 preferences 中的 memory_auto_learn（默认 true）。
func MemoryAutoLearnEnabled(prefs map[string]interface{}) bool {
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
